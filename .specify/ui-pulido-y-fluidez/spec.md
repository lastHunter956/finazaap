# Especificación — Pulido Visual y Fluidez Integral (`ui-pulido-y-fluidez`)

## 1. Objetivo
Elevar radicalmente la percepción visual y la fluidez táctil/animada de Moneo (`finazaap`) 100% offline, eliminando el aspecto sobrecargado de "cajas dentro de cajas", las caídas de FPS causadas por `BackdropFilter` en modales, los cortes secos de navegación y las 96 llamadas fantasma a `GoogleFonts`, respetando estrictamente los 4 temas oficiales (`_defaultDark`, `_diurno`, `_dia`, `_nocturno`), WCAG 2.1 AA/AAA y todos los archivos protegidos.

## 2. Requisitos Funcionales y Visuales
- **R1 — Fluidez y Movimiento Global (`O1`):**
  - Eliminar los 18 `BackdropFilter` en modales/diálogos/menús (conservando `BackdropFilter` únicamente en `LiquidGlassSurface` bajo tema `Diurno` con respaldo accesible).
  - Extender `MoneoSpringMotion` y `MoneoPressableScale` + haptics sutiles (`HapticFeedback.selectionClick`) a los **4 temas** cuando `!MediaQuery.disableAnimationsOf(context)`.
  - Transiciones suaves: `PageTransitionsTheme` unificado en `buildThemeData`, cross-fade suave (`150 ms`) al cambiar de pestaña en `MainContainer`, `AnimatedSize` + `AnimatedRotation` en acordeones de fecha de `Home`, y física de scroll coherente en toda la app.
  - Eliminar rebuilds redundantes en `Home` y el parpadeo de spinner al volver a la pestaña `Categorías`.
  - Aislar navegación inferior y tarjetas dashboard pesadas con `RepaintBoundary`.
- **R2 — Rediseño Fintech de `Home`, `TotalBalanceWidget` y Listas (`O2`):**
  - Limpiar `TotalBalanceWidget` eliminando el patrón "cajas dentro de cajas": foco principal en `Disponible`, anillo de progreso custom con puntas redondeadas (`StrokeCap.round`) y transición suave, métricas Ingresos/Egresos limpias sin doble borde, y selector de período en Bottom Sheet ergonómico con *drag handle* y sin blur animado.
  - Compactar la tarjeta contraída diaria en `Home` a una fila escaneable limpia, y modernizar las filas de transacciones en `Home` y `TransactionListWidget` con contenedores de ícono tonales suaves (`12%`) sin bordes duros ni sombras negras pesadas, usando `FontFeature.tabularFigures()` en montos.
- **R3 — Tipografía Limpia 100% Offline y Modales Modernos (`O3`):**
  - Configurar `textTheme`, `bottomSheetTheme` (`showDragHandle: true`, radio `28`), `dialogTheme` y `snackBarTheme` en `buildThemeData` sin alterar los valores hexadecimales de los 4 temas oficiales.
  - Reemplazar las 96 llamadas fantasma a `GoogleFonts.outfit(...)` en `AiChatScreen` por `TextStyle` nativo 100% offline y consistente.
  - Migrar opciones de categoría y menús de acción hacia superficies limpias/bottom sheets en zona del pulgar y refinar `SettingsScreen` / `MoneoHeaderBar` / `ResponsibilitiesScreen`.

## 3. Restricciones Inmutables
- **Cero archivos protegidos modificados** (`transaction_service.dart`, `credit_card_calculator.dart`, `*.g.dart`, `build.gradle`, `AndroidManifest.xml`, `lib/core/security/*`).
- **No tocar `lib/Screens/statistics.dart`** (reservado para Fase 3 en `wt-f2-archive`).
- **100% offline:** cero dependencias nuevas, cero descargas de fuentes ni llamadas de red.
- **Retrocompatibilidad de pruebas:** mantener intactos los tokens de color de `AppTheme`, los `Key` y `Semantics` verificados por la suite actual, y soporte `360x640 @ TextScaler(1.35)` sin overflow.
