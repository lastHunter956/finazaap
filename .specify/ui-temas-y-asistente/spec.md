# Especificación — Rediseño de Temas (`Diurno`, `Día`, `Nocturno`) y Asistente Financiero

> **Módulo:** `ui-temas-y-asistente`
> **Estado:** Implementación completa en integración (pendiente de validación visual humana)
> **Fecha:** 2026-11-14
> **Rama de integración objetivo:** `integration/ui-temas-y-asistente`

---

## 1. Alcance por Tema

1. **`Diurno` (`AppThemeMode.diurno`) — Único tema con Apple HIG & Liquid Glass**
   - **Fundamentación oficial (Apple Human Interface Guidelines — Materials / Liquid Glass):**
     - **Capa funcional flotante vs. capa de contenido:** Liquid Glass se aplica únicamente a superficies funcionales flotantes que viven *encima* del contenido (barra inferior `CustomPillBottomNavBar`, cabecera flotante unificada y composer flotante en `AiChatScreen`), permitiendo que el contenido pase por debajo con `extendBody: true` y refracción/desenfoque gaussiano (`BackdropFilter` con `sigma: 22.0`). Nunca se aplica blur a tarjetas de contenido, listas, saldos ni gráficas.
     - **Anatomía del material en Flutter:** Tinte frío traslúcido multicapa (`#FFFFFF` 85% → 75% → `#EEF4FF` 78%), borde especular (`GradientBoxBorder` `1.2px` blanco cenital a azul frío), reflejo cenital interno superior (`1px`) y sombra ambiental bicapa, más lente activa Liquid Glass en controles/segmentos seleccionados.
     - **Prohibición de Glass-on-Glass y accesibilidad:** No se apila vidrio sobre vidrio ni se abusa de `BackdropFilter`. Cuando `MediaQuery` reporta `accessibleNavigation`, `highContrast` o `disableAnimations` (*Reduce Transparency / Increase Contrast* del HIG), `LiquidGlassSurface` conmuta a superficie escarchada opaca (`Color(0xF5FFFFFF)`) con borde reforzado `#8496B0` sin `BackdropFilter`.
   - **Contraste WCAG 2.1 AA/AAA:** Todos los pares de texto normal (`textPrimary`, `textSecondary`, `textHint`), acentos (`accent`, `secondaryAccent`) y estados (`income`, `expense`, `warning`, `error`) sobre `primaryBackground`, `cardBackground` y `darkBackground` cumplen `>= 4.71:1` (AA/AAA).

2. **`Día` (`AppThemeMode.dia`)**
   - Corrección de colores y contraste con paleta cálida limpia (`#F4EFE6`, `#FFFDF9`, `#FAF6F0`, `#E6DFD3`, `#0E665F`, `#92400E`, `#146C34`, `#B91C1C`) sin amarillo saturado ni texto morado/violeta.
   - Sin Liquid Glass ni blur. Todos los pares semánticos sobre las tres superficies cumplen `>= 4.54:1` (AA/AAA).

3. **`Default` (`AppThemeMode.defaultDark`)**
   - **Tokens intactos:** No se modifican sus colores ni su identidad, salvo la adopción de la nueva arquitectura del **Asistente Financiero (`AiChatScreen`)** común a los cuatro temas (con superficie sólida, sin glass).

4. **`Nocturno` (`AppThemeMode.nocturno`)**
   - Adopción oficial de **Dracula**: fondo `#282A36`, tarjetas `#21222C` (ANSI Black oficial para alcanzar contraste AA Normal `5.03:1` con rojo `#FF5555` y `4.53:1` sobre `#282A36`), control hundido `#191A21`, selección `#44475A`, texto `#F8F8F2`, secundario `#C6CEE0`, hint legible `#909EC7` (`>= 5.36:1` AA en las tres capas), comentario/borde `draculaComment` `#6272A4`, morado `#BD93F9`, rosa `draculaPink` `#FF79C6`, cian `#8BE9FD`, naranja `#FFB86C`, rojo `#FF5555` y verde `#50FA7B` usado como acento/indicador/montos y nunca como texto pequeño.
   - Sin Liquid Glass ni blur.

---

## 2. Rediseño del Asistente Financiero (`AiChatScreen`) y Ajustes Transversales

1. **Asistente Financiero en los 4 temas:**
   - Eliminar todos los accesos estáticos `AppColors.*` y colores oscuros/neón hardcodeados (`0xFF222939`, `0xFF52E2FF`, `Colors.white10`, `Colors.black26`, etc.), resolviendo íntegramente desde `context.appTheme`.
   - **Cabecera unificada compacta:** Título, estado del motor, selector segmentado `Simulador` / `Gemma IA` y pestañas `Consultas` / `Perfil Cognitivo` en una sola cabecera flotante (con `LiquidGlassSurface` en `Diurno` y sólida en `Día`, `Nocturno` y `Default`), sin desbordamiento horizontal en `320–360px`.
   - **Burbujas de ancho orgánico:** Corrección definitiva del bug `const Spacer()` en la fila de hora, usando `IntrinsicWidth` + `ConstrainedBox` para que textos cortos ocupen su ancho natural y textos largos con Markdown se adapten hasta el máximo sin desbordamiento.
   - **Composer flotante y soporte de teclado/textos largos:** Cápsula flotante con `LiquidGlassSurface` en `Diurno` y sólido tematizado en el resto, `TextField` multilínea (`minLines: 1, maxLines: 4`) y `LayoutBuilder` en estado vacío para tolerar teclado abierto (`viewInsets`) en pantallas móviles.
   - **Sugerencias y diálogos tematizados + `CurrencyHelper`:** Tarjetas horizontales de categorías/transacciones sugeridas, diálogos de edición, tablero de insights y métricas del perfil cognitivo unificados con `CurrencyHelper.format(...)` y colores del tema activo.
   - **Lógica intacta:** Se preservan `AiChatService`, el funcionamiento offline, el selector de motor, la configuración de URL de modelo Gemma y las operaciones con `TransactionService` / `CategoryService`.
2. **Limpieza solicitada en Ajustes:**
   - Eliminar el ítem `"Bandeja de Notificaciones (Demo Dev)"` (`settings_notifications_demo_tile`) de `lib/Screens/settings_screen.dart`.

---

## 3. Restricciones Inviolables

- **Archivos protegidos intactos:** No tocar `lib/data/transaction_service.dart`, `lib/data/credit_card_calculator.dart`, `lib/data/model/*.g.dart`, `android/app/build.gradle`, `android/app/src/main/AndroidManifest.xml` ni `lib/core/security/*`.
- **Docker obligatorio:** Todas las pruebas y análisis se ejecutan en `finazaap-flutter` (`docker-compose exec -T flutter-env ...`).
- **Validación humana antes de merge:** La rama `integration/ui-temas-y-asistente` permanece abierta sin merge a `main` y sin instalación en dispositivo físico hasta aprobación explícita del usuario.

---

## 4. Extensión Disciplinada (Fase 4 — Navegación/FAB, Conversación Editorial, Perfil Cognitivo, Encabezados y Movimiento `SpringSimulation`)

1. **Barra inferior (`CustomPillBottomNavBar`) y botones `+` (`FloatingActionMenu` y FABs locales):**
   - Clearance dinámico mediante `MoneoLayoutMetrics` y `MoneoNavBarScope` (calculando altura real de la barra, `viewPadding.bottom`, `viewInsets.bottom` del teclado y `MediaQuery.textScalerOf(context)`), inyectando el clearance efectivo hacia los `Scaffold` hijos en `MainContainer` cuando `extendBody` está activo (`Diurno`).
   - El último elemento de cada `ListView` / `CustomScrollView` / `SingleChildScrollView` despeja barra + FAB con `MoneoLayoutMetrics.scrollBottomPadding`.
   - Corrección de contraste AA en los botones `+` (`FloatingActionMenu`, `CategoriesScreen`, `ResponsibilitiesScreen`) usando `t.buttonBackground` / `t.buttonForeground`.

2. **Conversaciones modernas en `AiChatScreen`:**
   - Lectura editorial limpia sin repetición de círculos/avatares AI, cabeceras repetidas `"Asistente"`, bordes cian ni sombras multicapa en burbujas o reportes Markdown.
   - Tarjetas estructuradas reservadas exclusivamente para sugerencias accionables (`INGRESO`/`GASTO`, `CurrencyHelper`, acciones `Descartar` / `Editar` / `Guardar`).
   - Prohibición estricta de `LiquidGlassSurface` / `BackdropFilter` en burbujas, sugerencias y reportes.

3. **Perfil Cognitivo coherente (`AiChatScreen`):**
   - Presentación editorial de métricas existentes de `AiChatService` sin inventar puntajes ni porcentajes de salud financiera, eliminando marcas de agua decorativas (`90px`) y truncamientos artificiales (`.substring(0, 12)...`), con salto adaptativo entre cuadrícula 2×2 y filas de ancho completo según ancho útil (`< 380`) y `TextScaler` (`scale(14) > 16.5`).

4. **Encabezados unificados (`MoneoHeaderBar` + `MoneoSegmentedControl`):**
   - Tres variantes diferenciadas: `primaryTab` (5 pestañas raíz), `subScreen` (5 pantallas de detalle) y `form` (3 formularios de captura), operando 100% offline con `TextStyle` nativo y altura dinámica (`preferredHeightFor`) calibrada para `TextScaler` y badges.
   - `AiChatScreen` conserva su cabecera unificada flotante como referencia visual del diseño.

5. **Movimiento físico real exclusivo en `Diurno` (`MoneoSpringMotion` y `MoneoPressableScale`):**
   - Continuidad de selección en `CustomPillBottomNavBar` y `MoneoSegmentedControl`, y respuesta táctil discreta (`pressedScale: 0.965`/`0.97`), accionados por `SpringSimulation` (`stiffness: 380.0`, `damping: 30.0`, `mass: 1.0`) y desactivados automáticamente cuando `MediaQuery.disableAnimations` está activo.
