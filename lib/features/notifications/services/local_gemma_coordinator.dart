import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:finazaap/services/device_capability_service.dart';

typedef GemmaModelLoader = Future<InferenceModel> Function({
  required int maxTokens,
  required PreferredBackend preferredBackend,
});

/// Coordinador único del ciclo de vida de Gemma 4 E2B en RAM.
///
/// Garantiza que nunca existan dos instancias simultáneas de `FlutterGemma`
/// entre `AiChatService` y `GemmaClassifierAdapter`:
/// - Serializa el acceso mediante mutex asíncrono.
/// - Verifica RAM disponible antes de cargar el modelo local (`>= 1.8 GB` y `!lowMemory`).
/// - Permite carga efímera por lote (`releaseAfterBatch()`) para liberar RAM al terminar.
/// - Libera el modelo automáticamente ante `didHaveMemoryPressure` o pausa de la app.
class LocalGemmaCoordinator with WidgetsBindingObserver {
  static const double minAvailableRamGb = 1.8;

  static final LocalGemmaCoordinator instance = LocalGemmaCoordinator._internal();

  LocalGemmaCoordinator._internal()
      : _capabilityCheck = DeviceCapabilityService.check,
        _modelLoader = _defaultModelLoader;

  @visibleForTesting
  LocalGemmaCoordinator.custom({
    required Future<DeviceCapabilityResult> Function() capabilityCheck,
    required GemmaModelLoader modelLoader,
    Future<void> Function()? ensureInitialized,
  })  : _capabilityCheck = capabilityCheck,
        _modelLoader = modelLoader,
        ensureGemmaInitialized = ensureInitialized;

  static Future<InferenceModel> _defaultModelLoader({
    required int maxTokens,
    required PreferredBackend preferredBackend,
  }) {
    return FlutterGemma.getActiveModel(
      maxTokens: maxTokens,
      preferredBackend: preferredBackend,
    );
  }

  /// Hook registrado en `main.dart` para inicializar `FlutterGemma` bajo demanda.
  Future<void> Function()? ensureGemmaInitialized;

  final Future<DeviceCapabilityResult> Function() _capabilityCheck;
  final GemmaModelLoader _modelLoader;

  InferenceModel? _activeModel;
  int _activeMaxTokens = 0;
  bool _chatActive = false;
  bool _observerRegistered = false;
  Future<void> _lockChain = Future<void>.value();

  bool get hasLoadedModel => _activeModel != null;
  int get activeMaxTokens => _activeMaxTokens;
  bool get isChatActive => _chatActive;

  /// Registra el observador de ciclo de vida y presión de memoria del SO.
  void registerLifecycleObserver() {
    if (_observerRegistered) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    } catch (_) {
      // Entornos sin WidgetsBinding inicializado.
    }
  }

  /// Indica si el Chat de IA está usando activamente el modelo local.
  void setChatActive(bool active) {
    _chatActive = active;
  }

  /// Verifica en tiempo real si el dispositivo tiene RAM suficiente para cargar
  /// Gemma 4 E2B sin riesgo de cierre por OOM.
  Future<bool> hasEnoughRamForLocalModel() async {
    try {
      final cap = await _capabilityCheck();
      if (cap.lowMemory) return false;
      if (cap.availRAMGB != null && cap.availRAMGB! < minAvailableRamGb) {
        return false;
      }
      return cap.hasEnoughRAM;
    } catch (_) {
      return false;
    }
  }

  /// Ejecuta [action] de forma exclusiva sobre la única instancia de Gemma local.
  ///
  /// Si [keepAliveAfter] es `false` y el chat no está activo, libera la RAM
  /// inmediatamente al concluir.
  Future<T?> runExclusive<T>({
    required int maxTokens,
    required Future<T?> Function(InferenceModel model) action,
    bool keepAliveAfter = false,
  }) {
    final completer = Completer<T?>();
    _lockChain = _lockChain.then((_) async {
      try {
        final model = await _acquireModelLocked(maxTokens: maxTokens);
        if (model == null) {
          completer.complete(null);
          return;
        }
        final result = await action(model);
        if (!keepAliveAfter && !_chatActive) {
          await _releaseModelLocked();
        }
        completer.complete(result);
      } catch (e, st) {
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        }
      }
    });
    return completer.future;
  }

  Future<InferenceModel?> _acquireModelLocked({required int maxTokens}) async {
    if (_activeModel != null && _activeMaxTokens >= maxTokens) {
      return _activeModel;
    }

    final ramOk = await hasEnoughRamForLocalModel();
    if (!ramOk) {
      return null;
    }

    if (_activeModel != null) {
      await _releaseModelLocked();
    }

    if (ensureGemmaInitialized != null) {
      await ensureGemmaInitialized!();
    }

    try {
      _activeModel = await _modelLoader(
        maxTokens: maxTokens,
        preferredBackend: PreferredBackend.gpu,
      );
      _activeMaxTokens = maxTokens;
      return _activeModel;
    } catch (_) {
      // Fallback seguro de GPU -> CPU si el backend GPU falla en el dispositivo.
      try {
        _activeModel = await _modelLoader(
          maxTokens: maxTokens,
          preferredBackend: PreferredBackend.cpu,
        );
        _activeMaxTokens = maxTokens;
        return _activeModel;
      } catch (_) {
        _activeModel = null;
        _activeMaxTokens = 0;
        return null;
      }
    }
  }

  Future<void> _releaseModelLocked() async {
    final model = _activeModel;
    _activeModel = null;
    _activeMaxTokens = 0;
    if (model != null) {
      try {
        await model.close();
      } catch (_) {}
    }
  }

  /// Libera la RAM del modelo al finalizar un lote de notificaciones (si el chat no está activo).
  Future<void> releaseAfterBatch() {
    if (_chatActive || _activeModel == null) {
      return Future<void>.value();
    }
    return releaseModel();
  }

  /// Libera incondicionalmente el modelo cargado de la RAM.
  Future<void> releaseModel() {
    final completer = Completer<void>();
    _lockChain = _lockChain.then((_) async {
      await _releaseModelLocked();
      completer.complete();
    });
    return completer.future;
  }

  @override
  void didHaveMemoryPressure() {
    // Android avisó presión de memoria: liberar Gemma local de inmediato para evitar OOM.
    unawaited(releaseModel());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(releaseModel());
    }
  }
}
