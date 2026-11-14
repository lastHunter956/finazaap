# Especificación — Rediseño de Temas (`Diurno`, `Día`, `Nocturno`) y Asistente Financiero

> **Módulo:** `ui-temas-y-asistente`
> **Estado:** Fase 1 en ejecución (Tokens y Contraste)
> **Fecha:** 2026-11-14
> **Rama de integración objetivo:** `integration/ui-temas-y-asistente`

---

## 1. Alcance por Tema

1. **`Diurno` (`AppThemeMode.diurno`)**
   - **Fase 1:** Corrección completa de tokens de color, separación de capas y contraste WCAG 2.1 AA/AAA (sin Liquid Glass ni `BackdropFilter` todavía).
   - **Fase 3:** Único tema que recibirá tratamiento **Liquid Glass** moderado exclusivamente en elementos funcionales pequeños y fijos (barra inferior de navegación `CustomPillBottomNavBar` y composer de `AiChatScreen`; opcionalmente cabecera flotante del chat si mejora jerarquía), con variante sólida de respaldo y sin blur en tarjetas de contenido, listas, gráficas, movimientos ni saldos.
2. **`Día` (`AppThemeMode.dia`)**
   - **Fase 1:** Solo corrección de colores y contraste. Elimina la mezcla de amarillo saturado (`#FEF3C7`), texto morado (`#1E1B4B`), hints violeta (`#4F46E5`) y naranja dominante (`#D97706`) por una paleta cálida, limpia y coherente con contraste AA/AAA.
   - Sin glass, sin blur y sin rediseño estructural.
3. **`Default` (`AppThemeMode.defaultDark`)**
   - **Intacto:** Prohibido modificar cualquiera de sus tokens.
4. **`Nocturno` (`AppThemeMode.nocturno`)**
   - **Fase 1:** Adopción de la paleta oficial **Dracula**:
     - Fondo: `#282A36`
     - Texto principal: `#F8F8F2`
     - Comentarios / hint: `#6272A4`
     - Selección / superficie elevada: `#44475A` (con superficie de tarjetas intermedia `#313442` y control hundido `#1E1F29`)
     - Morado: `#BD93F9`
     - Rosa: `#FF79C6`
     - Verde: `#50FA7B` (usado como acento/indicador y montos, **no** como color de texto pequeño)
     - Cian: `#8BE9FD`
     - Naranja: `#FFB86C`
     - Rojo: `#FF5555`
   - Sin glass en ninguna fase.

---

## 2. Alcance por Fases

- **Fase 1 (Activa): Tokens y Contraste**
  - Actualizar tokens en `lib/themes/app_theme_data.dart` (`_diurno`, `_dia`, `_nocturno`, conservando `_defaultDark` intacto).
  - Eliminar colores hardcodeados que rompen temas en `lib/widgets/total_balance_widget.dart`, `lib/Screens/settings_screen.dart`, `lib/Screens/statistics.dart` y `lib/widgets/custom_pill_bottom_nav_bar.dart` (sin añadir glass/blur ni cambiar estructura).
  - Agregar suite automatizada de contraste WCAG 2.1 y paletas (`test/themes/app_theme_contrast_test.dart`).
  - Validar en Docker (`dart analyze`, `flutter test -j 1`) y esperar validación visual del usuario en `integration/ui-temas-y-asistente`.
- **Fase 2 (Pendiente de validación de Fase 1): Asistente Financiero (`AiChatScreen`)**
  - Corregir el bug del `Spacer()` que fuerza las burbujas al 76% de ancho.
  - Eliminar colores hardcodeados y bordes neón fijos.
  - Unificar las tres barras superiores en una cabecera única.
  - Burbujas de ancho orgánico, composer flotante y tarjetas de sugerencias tematizadas con `CurrencyHelper`.
- **Fase 3 (Pendiente de validación de Fase 2): Liquid Glass en `Diurno`**
  - Aplicar glass moderado (`BackdropFilter` / `ImageFiltered`) exclusivamente en barra inferior y composer del chat para `Diurno`, con respaldo sólido para accesibilidad y validación en `Samsung SM_S721B`.

---

## 3. Restricciones Inviolables

- **Archivos protegidos intactos:** No tocar `lib/data/transaction_service.dart`, `lib/data/credit_card_calculator.dart`, `lib/data/model/*.g.dart`, `android/app/build.gradle`, `android/app/src/main/AndroidManifest.xml` ni `lib/core/security/*`.
- **Docker obligatorio:** Todas las pruebas y análisis se ejecutan en `finazaap-flutter` (`docker-compose exec -T flutter-env ...`).
- **Validación humana antes de merge:** La rama `integration/ui-temas-y-asistente` permanece abierta sin merge a `main` hasta aprobación explícita del usuario.
