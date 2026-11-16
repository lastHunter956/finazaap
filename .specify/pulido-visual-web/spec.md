# Especificación — Pulido Visual Incremental Web (`pulido-visual-web`)

> **Módulo:** `pulido-visual-web`
> **Base:** `c432642` (`main`)
> **Rama de integración:** `integration/pulido-visual-web`
> **Exclusión obligatoria:** `lib/Screens/statistics.dart` (reservado para Fase 2 en `wt-f2-archive`).

---

## 1. Objetivo y Alcance

Aplicar una pasada de **pulido visual incremental** (sin rediseño total ni nuevas paletas/fuentes/dependencias) sobre Moneo (`finazaap`), alineada con [moneo-ui-design](file:///Volumes/ADATA%20SD620/Programacion%207.0/moneo/finazaap/.agents/skills/moneo-ui-design/SKILL.md), para mejorar accesibilidad, consistencia visual, jerarquía balance-first y resiliencia en `360×640` con `TextScaler 1.35x`.

### Lote P0 — Accesibilidad y Tokens
1. **Contraste AA en tema `Default` (`_defaultDark`):** Ajustar `textHint`, `secondaryAccent` y `expense`/`error` en `lib/themes/app_theme_data.dart` (con autorización explícita del usuario) para que cumplan WCAG 2.1 AA (`>= 4.5:1`) sobre `primaryBackground`, `cardBackground` y `darkBackground`, actualizando `test/themes/app_theme_contrast_test.dart`.
2. **Targets táctiles `>= 44×44 dp` (meta `48×48 dp`):** `_HeaderBackButton` (`MoneoHeaderBar`), botones AppBar de `Home` (Pendientes/Chat), botón ocultar saldo en `Cuentas`, botón Atrás/Enviar/tabs de motor en `AiChatScreen`, chips de filtro, acciones de `PendingTransactionCard` y controles de `TotalBalanceWidget`.
3. **Semántica (`Semantics` + `Tooltip`):** Añadir etiquetas accesibles en botones Atrás, botones AppBar de `Home`, toggle de visibilidad de saldo, cabeceras colapsables de días en `Home`, teclado PIN (`PinCodeScreen`), tarjetas de tema en `SettingsScreen`, enviar/detener chat y tabs de motor.
4. **Migración de colores hardcodeados y tokens unificados:** Reemplazar colores literales (`Colors.green`, `Colors.redAccent`, `Colors.blueAccent`, `Colors.amber`, `Colors.white` sobre fondos claros, etc.) por `context.appTheme.*` y `AppColors.getReadableColor(...)`.
5. **Consistencia de radios y sombras:** Estandarizar radios de tarjeta y controles usando `AppSizes` (`lib/themes/app_sizes.dart`) y consolidar sombras pesadas/múltiples en 1 sombra sutil en temas claros (`0` o sutil en oscuros).

### Lote P1 — Home y Transacciones
1. **Simplificación de `Home` y `TotalBalanceWidget`:** Reducir la densidad de controles dentro de la tarjeta de saldo (de 9 acciones compitiendo a 3–4 claras: gestionar cuentas, selector de mes/año, filtro de movimientos y FAB `+`), mover el filtro `Todos`/`Gastos`/`Ingresos` a `MoneoSegmentedControl` junto al historial y hacer prominente el saldo `"Disponible"` (`32–36px` con `FontFeature.tabularFigures()`).
2. **Anillo de progreso robusto:** Cuando `gastos > ingresos`, mostrar feedback visual completo de exceso (`1.0` en `t.expense`) en lugar de vaciarse a `0%`.
3. **Agrupación y filas de transacciones:**
   - Encabezados diarios legibles con `DateFormat(..., 'es')` (`Hoy · dd MMM`, `Ayer · dd MMM`, o `EEE dd MMM yyyy`).
   - Cada fila muestra **ícono con color-coding por categoría guardada** (vía `_categoryColors` + `AppColors.getReadableColor`), **título** (`Categoría - Detalle` o `Transferencia`), **fecha/hora (`HH:mm`) + cuenta/ruta**, y **monto alineado con `tabularFigures()`**.
4. **Estado vacío accionable en `Home`:** Cuando no hay transacciones visibles para el período/filtro, mostrar estado vacío claro con CTA directo para registrar movimiento.

### Lote P2 — Estados Vacíos y Overflows `1.35x`
1. **Estados vacíos con CTA:** Añadir estado vacío accionable en `SelectAccountScreen` (`"Crear cuenta"`), `ResponsibilitiesScreen` (`"Nueva obligación"`), y `AnnualProjectionScreen` (`"Nueva obligación"`), sin siembra automática de datos.
2. **Corrección de riesgos de overflow a `360×640 @ 1.35x`:**
   - `TotalBalanceWidget`: envolver columna izquierda de saldo en `Expanded`/`Flexible` y proteger modal selector.
   - `SelectAccountScreen`: proteger `_buildTotalBalanceSection` y badges de tarjetas contra overflow horizontal.
   - `DailyTransactionsScreen`: sustituir/ajustar `_CollapsibleHeaderDelegate` para escalado `1.35x` sin `RenderFlex overflow`.
   - `ResponsibilitiesScreen`: ajustar `_StickyCategoryDelegate` (altura dinámica por `textScaler`) y ancho del monto en `ResponsibilityListItem`.
   - `PendingTransactionCard`: adaptar barra de acciones con `Wrap` o botones flexibles a `1.35x`.
   - `FloatingActionMenuScreen` y `ResponsibilityActionsMenu`: envolver contenido modal en `SingleChildScrollView`.
   - `PinCodeScreen`: evitar compresión de teclado en `640px @ 1.35x`.
   - `AnnualProjectionScreen`: eliminar doble padding inferior.

---

## 2. Restricciones Inviolables
- **NO tocar `lib/Screens/statistics.dart`.**
- **NO tocar `main` ni `wt-f2-archive`.**
- **NO tocar archivos protegidos** (`transaction_service.dart`, `credit_card_calculator.dart`, `*.g.dart`, `android/app/build.gradle`, `AndroidManifest.xml`, `lib/core/security/*`).
- **NO compilar APK ni instalar en dispositivo ni ejecutar Maestro.**
- **Validación obligatoria por lote:** Widget tests (`360×640`, `TextScaler 1.35`, `Semantics`, contraste) + `dart analyze` + `flutter test --no-pub -j 1` en Docker + `flutter build web` y verificación visual Web.
