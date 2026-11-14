# Punto de Continuidad (`docs/audit/CONTINUITY_STATE.md`)

> **Fecha:** 2026-11-14  
> **Estado de cuota:** No consultable desde herramientas (no se inventa valor numérico).  
> **Rama / Commit base:** `main` @ `bab211fcc9243e89b050fd1a40cb9c25157d7fcb` (`bab211f`), árbol limpio salvo `?? docs/audit/`.  
> **Agentes / Tareas activas:** 0 subagentes activos, 0 tareas en segundo plano.

---

## 1. Solicitud Original y Alcance
- **Fase 1 (Auditoría):** Auditoría de solo lectura en 4 frentes de Moneo (`finazaap`): (1) lógica y contabilidad, (2) fluidez y rendimiento, (3) modelo IA on-device (`flutter_gemma` / por qué tarda o falla en el teléfono), y (4) seguridad integral.
- **Fase 2 (Paquete de Ejecución):** Convertir los hallazgos en un paquete verificable en `docs/audit/` para ejecutar en otro chat (con este mismo modelo y multiagente controlado, máx. 2 subagentes simultáneos heredando modelo), **sin modificar código, configuración, dependencias ni archivos protegidos**.

---

## 2. Base de Git y Relación con UI (`integration/ui-temas-y-asistente`)
- `integration/ui-temas-y-asistente` (incluyendo `af1fbf5`) ya está fusionada por `--ff-only` en `main` (`bab211f`) y retirada.
- Modificó 28 archivos entre `165c1c1..bab211f`. Los puntos de mayor riesgo de conflicto para futuras tareas son: `lib/Screens/ai_chat_screen.dart`, `lib/Screens/home.dart`, `lib/widgets/total_balance_widget.dart`, `lib/Screens/statistics.dart`, `lib/Screens/main_container.dart`.
- **Regla UI:** No alterar `app_theme_data.dart`, `liquid_glass_surface.dart`, `moneo_header_bar.dart`, `custom_pill_bottom_nav_bar.dart` ni sus tests.

---

## 3. Estado Real de Verificación (Lectura vs Reporte vs Reproducción)
- **Confirmados por lectura directa en código / pub-cache:**
  - `flutter_gemma: 1.0.2` (`pubspec.lock`), soporte de `ModelType.gemma4` (`model.dart:4`), `maxTokens` = KV-cache total con mínimo `1024` (`litert_lm_engine.dart:27-34`), `createChat()` cierra sesión previa (`ffi_inference_model.dart:115,305`) y `addQueryChunk` concatena texto en `.litertlm` Android (`extensions.dart:80-84`, `ffi_inference_model.dart:369-375`).
  - `assets/models/gemma.litertlm` = `2.4G` (`2,588,147,712` bytes) no incluido en `pubspec.yaml:81-83`; `MainActivity.kt` reporta `totalMem`; `AndroidManifest.xml` principal y plugins de pub-cache no declaran `INTERNET` ni `allowBackup="false"`.
  - Muestras directas en código de: `M1`–`M10`, `SEC-01`–`SEC-13` (con matiz en `SEC-01`: 4 cajas de notificaciones sí usan `HiveAesCipher`, `data`/`responsibilities`/`SharedPreferences` no), `L1.1`–`L1.13`, `L2.1`–`L2.6`, `L3.1`–`L3.5`, `L4.1`–`L4.6`, `L5.1`–`L5.4`, `P1.1`–`P1.3`, `P2.1` (bajada a ALTO por ser animación única de 20 s), `P2.2`, `P3.1`, `P3.2`.
- **Hipótesis pendientes (NO verificadas en ejecución real / dispositivo físico):**
  - Merged manifest real de `--release` (no existe `build/app/intermediates/merged_manifests/release/AndroidManifest.xml` en disco; se verificará en `T0.2`).
  - Todas las cifras de tiempos en segundos/ms, FPS y `tokens/s` son **estimaciones**, NO mediciones en dispositivo físico.
  - Estado real de los datos instalados en el teléfono (`R5CY21GE9YY`).
- **Fallos reproducidos con pruebas:** **0** hasta ejecutar `T0.1` (`test/audit/accounting_repro_test.dart`).
- **Hallazgos descartados:** **0** hasta la fecha (`P1.4`, `P2.3`, `P2.4`, `P3.3`, `P3.5` fueron confirmados por lectura directa en el último lote, corrigiendo `add_expense.dart:767` y `home.dart:1608,1633`).

---

## 4. Trabajo Realizado, Pendientes y Siguiente Paso
- **Hecho:** Paquete completo en `docs/audit/` (`README.md`, `CONTINUITY_STATE.md`, `FINDINGS.md`, `DECISIONS.md`, `EXECUTION_PLAN.md`, `START_HERE_NEW_CHAT.md` y 17 fichas en `docs/audit/tasks/`).
- **Pendiente (próximo chat de ejecución):**
  1. Ejecutar **Ola 0** (`T0.1` y `T0.2` en paralelo con `Model: 'inherit'` o secuencial en Docker).
  2. Responder las decisiones `D1`–`D8` en `docs/audit/DECISIONS.md` antes de iniciar Olas 1–3.
- **Primera tarea apta para ejecución:** **`T0.1`** ([T0.1](file:///Volumes/ADATA%20SD620/Programacion%207.0/moneo/finazaap/docs/audit/tasks/T0.1-diagnostico-datos-y-tests-contables.md)) y **`T0.2`** ([T0.2](file:///Volumes/ADATA%20SD620/Programacion%207.0/moneo/finazaap/docs/audit/tasks/T0.2-baseline-docker-y-manifest.md)) — no tocan código productivo ni requieren decisiones `D1`–`D8`.
