# Desglose de Tareas por Lotes (`tasks.md`)

> Regla de avance: cada lote debe pasar `dart analyze` y la suite completa `flutter test -j 1` en Docker (`finazaap-flutter-env:3.44.2`) antes de pasar al siguiente.

---

## Lote 0 — Especificación y Skill Local
- [x] Crear `.specify/onboarding-y-mejoras-ui/spec.md`, `plan.md` y `tasks.md`.
- [x] Crear `.agents/skills/moneo-ui-design/SKILL.md` (100% offline, sin red/telemetría/hooks externos).

## Lote 1 — Mejoras UI Incrementales
- [x] `lib/Screens/annual_projection_screen.dart`: agregar `Semantics` + `tooltip` en FAB y `MoneoLayoutMetrics.scrollBottomPadding` al `CustomScrollView`.
- [x] `lib/Screens/statistics.dart`: reemplazar `date.substring(0, 6) + '...'` por formato compacto legible sin truncamiento arbitrario.
- [x] `lib/features/notifications/presentation/screens/pending_transactions_screen.dart`: usar `MoneoLayoutMetrics.scrollBottomPadding(context, hasFab: false)`.
- [x] `lib/Screens/categories_screen.dart`: agregar estado vacío accionable con explicación y CTA `"Crear categoría"` (sin siembra automática).
- [x] `lib/Screens/add.dart`, `lib/Screens/add_expense.dart`, `lib/Screens/transfer.dart`, `lib/widgets/add_account_dialogs.dart`: unificar mensajes de validación en español, validar montos inválidos o `<= 0`, y preservar estado sin cerrar pantalla ante error.
- [x] **Pruebas Lote 1:** Widget tests dirigidos (`360x640`, `TextScaler.linear(1.35)`), `dart analyze` y suite Flutter completa en Docker (`226/226` pasaron).

## Lote 2 — Onboarding Completo
- [ ] Crear `lib/services/onboarding_service.dart` (`onboarding_completed`, `onboarding_skipped`, `onboarding_last_step`, detección de usuario existente sin alterar ni borrar datos, helpers idempotentes).
- [ ] Crear `lib/Screens/onboarding_screen.dart` (5 pasos, categorías sugeridas seleccionables + creación propia sin siembra automática, primera cuenta opcional, primer ingreso/gasto real opcional, omisión, abandono a mitad/reanudación, accesibilidad AA/48dp/`Semantics`/`TextScaler(1.35)`).
- [ ] Conectar `lib/presentation/screens/auth_splash_screen.dart` y añadir reapertura `"Guía inicial"` en `lib/Screens/settings_screen.dart`.
- [ ] **Pruebas Lote 2:** Unit tests de `OnboardingService`, widget tests de los 5 pasos/omisión/abandono/reanudación/usuario existente/no duplicación/accesibilidad, `dart analyze` y suite Flutter completa en Docker.

## Lote 3 — Integración y Validación
- [ ] Consolidar cambios y verificar suite completa en Docker.
- [ ] Crear flujos `.maestro/` con datos sintéticos para `com.example.finazaap.validation` (sin instalar APKs sin aprobación explícita con metadatos completos).
