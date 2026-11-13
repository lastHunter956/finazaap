---
trigger: always_on
---

# Regla: Protección de Archivos Críticos

Queda **prohibido** crear, editar, renombrar o eliminar cualquiera de los siguientes archivos o directorios sin **aprobación explícita del usuario** antes de aplicar el cambio:

- `lib/data/transaction_service.dart` — Única puerta de entrada para saldos en `SharedPreferences` y sincronización con `ResponsibilityService` y `Hive`.
- `lib/data/credit_card_calculator.dart` — Fuente de verdad única para cálculo de deuda y cuotas de tarjetas de crédito.
- `lib/data/model/*.g.dart` — Adaptadores Hive generados por `build_runner` (`add_date.g.dart`, `responsibility.g.dart`). No editar manualmente; solo regenerar tras aprobación de cambios en modelos.
- `android/app/build.gradle` — Configuración de compilación, `applicationId`, SDKs y firma de Android.
- `android/app/src/main/AndroidManifest.xml` — Permisos, servicios nativos y componentes declarados de Android.
- `lib/core/security/*` — Servicios de cifrado (`encryption_service.dart`, almacenamiento seguro y llaves maestras).

## Protocolo ante un cambio necesario

1. Si una tarea requiere modificar alguno de estos archivos, **detente antes de editar** y solicita aprobación explícita al usuario explicando qué archivo se tocará, por qué y qué invariantes se ven afectados.
2. Verifica también si el cambio impacta archivos de riesgo relacionados documentados en [PROJECT_AUDIT.md](file:///Volumes/ADATA%20SD620/Programacion%207.0/moneo/finazaap/docs/discovery/PROJECT_AUDIT.md) (como `lib/data/responsibility_service.dart`, `lib/providers/pin_provider.dart` o `android/app/proguard-rules.pro`).
3. Esta regla es complementada a nivel de ejecución por el hook `PreToolUse` en `.agents/hooks/check_protected_files.py`.
