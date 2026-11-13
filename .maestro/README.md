# Flujos E2E con Maestro (`.maestro/`)

Este directorio almacena los flujos de pruebas End-to-End (E2E) en formato YAML para Maestro sobre la aplicación Moneo (`finazaap`).

## Uso previsto

- Coloca aquí los flujos `.yaml` por pantalla o viaje crítico del usuario (ej. `auth_pin.yaml`, `add_expense.yaml`, `credit_card_payment.yaml`).
- Todos los flujos deben poder ejecutarse 100% offline.
- Antes de crear nuevos flujos, revisa los criterios de aceptación definidos en `.specify/` y la regla de desarrollo en `.agents/rules/flujo-desarrollo.md`.
