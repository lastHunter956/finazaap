# Plan Técnico: Onboarding Inicial y Mejoras Incrementales de UI

> **Rama:** `agent/ui/onboarding-y-mejoras` (desde `main` `24902ce`)  
> **Entorno de build y pruebas:** Docker `finazaap-flutter` (`dart analyze`, `flutter test -j 1`)  
> **Skill rectora:** `.agents/skills/moneo-ui-design/SKILL.md`

---

## 1. Arquitectura y Decisiones Técnicas

1. **Aislamiento de estado de onboarding (`lib/services/onboarding_service.dart`):**
   - Encapsula lectura/escritura de `onboarding_completed`, `onboarding_skipped` y `onboarding_last_step` sobre `PrefsManager`.
   - Expone `evaluateStartupState()` para distinguir usuario nuevo vs usuario existente consultando `AccountService.getActiveAccounts()`, `AccountService.getDeletedAccountNames()`, `CategoryService.getCategories(...)` y la caja Hive `'data'` en modo solo lectura.
   - Expone helpers idempotentes para guardar categorías seleccionadas (merge por conjunto único sin duplicados) y validar nombre único de cuenta antes de persistir.

2. **Pantalla modular de Onboarding (`lib/Screens/onboarding_screen.dart`):**
   - `OnboardingScreen({this.initialStep = 0, this.isReopened = false})`.
   - `PageController(initialPage: initialStep)` con `NeverScrollableScrollPhysics`.
   - `PopScope` para retroceder entre pasos y confirmar salida en el paso inicial.
   - Reutiliza `MoneoHeaderBar`, `MoneoSegmentedControl`, `AppColors`, `context.appTheme`, `CurrencyHelper`, `AlertHelper` y `CategoryService`/`AccountService`/`TransactionService` (vía llamadas públicas existentes, sin modificar `transaction_service.dart`).

3. **Integración en puntos de entrada existentes:**
   - `lib/presentation/screens/auth_splash_screen.dart`: tras verificar PIN/biometría (o si no hay PIN), consulta `OnboardingService.shouldShowOnboarding()`. Si es `true`, navega a `OnboardingScreen` en lugar de `MainContainer`.
   - `lib/Screens/settings_screen.dart`: añade fila `"Guía inicial"` que abre `OnboardingScreen(isReopened: true, initialStep: 0)` con `Navigator.push`.

4. **Mejoras incrementales de UI (sin rediseño):**
   - `annual_projection_screen.dart`: `Semantics` + `tooltip` en FAB y `MoneoLayoutMetrics.scrollBottomPadding` al final del `CustomScrollView`.
   - `statistics.dart`: `formatDate` legible con `DateFormat('dd MMM', 'es')` y `FittedBox` sin `.substring(0, 6) + '...'`.
   - `pending_transactions_screen.dart`: `MoneoLayoutMetrics.scrollBottomPadding(context, hasFab: false)`.
   - `categories_screen.dart`: estado vacío con CTA `"Crear categoría"` invocando `_showCategoryDialog(type: type)`.
   - `add.dart`, `add_expense.dart`, `transfer.dart`, `add_account_dialogs.dart`: mensajes uniformes vía `AlertHelper.warning` + preservación de campos.

---

## 2. Restricciones y Verificaciones de Seguridad

- **Sin archivos protegidos modificados:** `transaction_service.dart`, `credit_card_calculator.dart`, `*.g.dart`, `build.gradle`, `AndroidManifest.xml`, `lib/core/security/*`.
- **Sin dependencias nuevas** en `pubspec.yaml` ni fuentes remotas.
- **Tests en `FakeAsync`:** Usar mocks o `SharedPreferences.setMockInitialValues({})` y cajas Hive en memoria/temporales para evitar timeouts de E/S en widget tests (según `docs/handoff/LESSONS.md`).
- **Validación Maestro:** Únicamente cuando toda la suite Flutter esté verde, sobre `com.example.finazaap.validation` con datos sintéticos y protocolo explícito de aprobación si se requiere instalar APK.
