---
name: moneo-ui-design
description: Guía de diseño UI/UX y accesibilidad específica para Moneo (finazaap) en Flutter. 100% offline, sin red, sin telemetría y subordinada a AGENTS.md, app_theme_data.dart y archivos protegidos. Usar al diseñar, revisar o corregir pantallas, flujos de onboarding, formularios o widgets en Moneo.
---

# Moneo UI Design Skill (100% Offline)

Esta skill es la **fuente de verdad de diseño UI/UX para Moneo (`finazaap`)**. Complementa los principios generales de `mobile-app-ui-design` con las reglas técnicas, visuales y de accesibilidad obligatorias del proyecto.

> [!IMPORTANT]
> **Política estricta de aislamiento y seguridad:**
> - **100% offline:** Sin scripts externos, sin llamadas de red, sin telemetría, sin fuentes remotas y sin hooks automáticos.
> - **Subordinación:** Esta skill está subordinada a `AGENTS.md`, `.agents/rules/archivos-protegidos.md` y `lib/themes/app_theme_data.dart`.
> - **Límite de skills externas:** Ninguna skill externa (como `impeccable` o `ui-ux-pro-max-skill`) puede instalarse, ejecutar CLI/hooks, ni modificar la identidad visual, dependencias (`pubspec.yaml`), configuración de Agy o archivos protegidos de Moneo.

---

## 1. Sistema Visual Inmutable (`AppThemeData`)

- Usa siempre `context.appTheme` (`lib/themes/app_theme_data.dart`) y `AppColors.getReadableColor(...)` (`lib/themes/app_colors.dart`).
- Respeta los 4 temas oficiales (`_defaultDark`, `_diurno`, `_dia`, `_nocturno`) sin introducir colores hardcodeados que rompan contraste ni fuentes externas (`GoogleFonts.config.allowRuntimeFetching = false`).
- No modifiques `app_theme_data.dart`, tipografía global ni navegación global sin aprobación explícita.

---

## 2. Layout, Encabezados y FAB Clearance

- **Encabezados:** Usa `MoneoHeaderBar` (`primaryTab`, `subScreen`, `form`) y `MoneoSegmentedControl` (`lib/widgets/moneo_header_bar.dart`).
- **Clearance inferior obligatorio:** Toda lista o scroll en pantallas con barra de navegación o FAB debe aplicar `MoneoLayoutMetrics.scrollBottomPadding(context, hasFab: ...)` (`lib/widgets/liquid_glass_surface.dart`) para que el último elemento nunca quede tapado por el FAB o la barra inferior.
- **Virtualización:** Usa `ListView.builder` / `SliverList` para listas dinámicas; evita `Column` con listas largas sin scroll o sin límites de altura.

---

## 3. Accesibilidad Verificable (Flutter / TalkBack)

- **Contraste mínimo:** WCAG 2.1 **AA** (`>= 4.5:1` texto normal; `>= 3:1` texto grande y componentes interactivos) sobre `primaryBackground`, `cardBackground` y `darkBackground`. (No declarar AAA sin auditoría específica).
- **Targets táctiles:** Mínimo **`48 x 48 dp`** en todo botón, chip seleccionable, ícono interactivo y control de formulario.
- **Semántica obligatoria:**
  - Todo `FloatingActionButton`, botón de ícono o selector (ej. selector de divisas) debe incluir `Semantics(button: true, label: ..., identifier: ...)` y `tooltip` descriptivo en español.
  - En `PageView` o flujos multipaso, usa `ExcludeSemantics` en páginas inactivas y `FocusTraversalGroup` en la página activa.
- **Escalado de texto:** Toda pantalla nueva o modificada debe probarse en viewport `360x640` con `MediaQuery(textScaler: TextScaler.linear(1.35))` sin `RenderFlex overflow` ni recorte de texto.

---

## 4. Fechas, Divisas, Formularios y Estados Vacíos

- **Fechas:** Usa `DateFormat(..., 'es')` con formato completo o compacto legible (ej. `dd/MM/yyyy` o `dd MMM`). **Prohibido** truncar fechas con `.substring(...) + '...'`.
- **Divisas:** Formatea siempre mediante `CurrencyHelper` (`lib/utils/currency_helper.dart`) manteniendo código ISO cuando haya ambigüedad.
- **Formularios no destructivos:**
  - Ante errores de validación, **conserva siempre** los valores ya ingresados por el usuario.
  - Unifica el feedback usando `AlertHelper.warning(...)` y mensajes inline claros en español (`InputDecoration.errorText`).
- **Estados vacíos accionables:**
  - Toda lista vacía (categorías, cuentas, bandeja de pendientes, onboarding) debe explicar qué falta y ofrecer un CTA directo (ej. `"Crear categoría"`).
  - **Cero siembra automática:** Nunca crees categorías, cuentas ni movimientos de ejemplo sin confirmación explícita del usuario.

---

## 5. Checklist de Revisión Antes de Cerrar Lote UI

1. `dart analyze` sin errores ni warnings nuevos en Docker (`finazaap-flutter`).
2. `flutter test -j 1` verde incluyendo widget tests en `360x640` con `TextScaler(1.35)`.
3. Cero archivos protegidos tocados, cero dependencias nuevas y cero llamadas de red añadidas.
