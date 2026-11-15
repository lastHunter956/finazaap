# Especificación: Onboarding Inicial y Mejoras Incrementales de UI (Moneo)

> **Estado:** Borrador para revisión (Lote 0)  
> **Rama objetivo:** `agent/ui/onboarding-y-mejoras` (desde `main` `24902ce`)  
> **Alcance:** Onboarding inicial de 5 pasos + mejoras incrementales de UI en pantallas existentes.

---

## 1. Principios y Límites de Privacidad y Datos

1. **Operación 100% local:** Moneo es una aplicación 100% local para sus funciones principales (gestión de categorías, cuentas, saldos y movimientos).
2. **Cero red/telemetría nueva:** Prohibido introducir analytics, telemetría, servicios remotos, fuentes remotas (`GoogleFonts.config.allowRuntimeFetching = false` en `lib/main.dart`) ni llamadas de red para diseño, onboarding o pruebas.
3. **Permiso `INTERNET` acotado:** El permiso `android.permission.INTERNET` existente en `android/app/src/main/AndroidManifest.xml` se mantiene únicamente para la funcionalidad ya definida de descarga bajo demanda de Gemma; no se amplía ni se utiliza para diseño, telemetría o skills externas.
4. **Formulación verificable de privacidad:** No se promete "sin rastreo" ni privacidad absoluta sin evidencia de auditoría completa. El texto oficial en el onboarding es:
   > *"Tus datos se guardan en tu dispositivo. Moneo no requiere una cuenta en la nube para usar sus funciones principales."*
5. **Cero siembra automática:** Prohibido sembrar categorías, cuentas o movimientos automáticamente. El usuario decide explícitamente qué categorías y cuentas crea.
6. **Archivos protegidos intactos:** No se modifican `lib/data/transaction_service.dart`, `lib/data/credit_card_calculator.dart`, `lib/data/model/*.g.dart`, `android/app/build.gradle`, `android/app/src/main/AndroidManifest.xml` ni `lib/core/security/*`. No se alteran esquemas Hive, cifrado, PIN ni reglas financieras.

---

## 2. Mapa de Pantallas y Navegación (Onboarding)

```text
AuthSplashScreen
  ├─ ¿onboarding_completed == true? ──► MainContainer (Home) [o PinCodeScreen si PIN activo]
  └─ ¿onboarding_completed == false? ─► Evaluación de usuario existente
        ├─ Usuario existente detectado ──► Marca onboarding_completed = true (sin mutar datos) ──► MainContainer
        └─ Usuario nuevo ────────────────► OnboardingScreen (Paso 0..4 / "Paso 1..5", initialStep = onboarding_last_step)
                                             ├─ Paso 1: Bienvenida breve
                                             ├─ Paso 2: Selección/creación de categorías (Egresos e Ingresos)
                                             ├─ Paso 3: Creación de primera cuenta (u omisión)
                                             ├─ Paso 4: Primer ingreso o gasto real (opcional)
                                             └─ Paso 5: Resumen final ──► MainContainer (Home)

SettingsScreen ──► "Guía inicial" ──► OnboardingScreen(isReopened: true, initialStep: 0) ──► Navigator.pop()
```

### Reglas de navegación
- **`PageView` controlado:** `NeverScrollableScrollPhysics` para evitar avanzar con *swipe* saltándose validaciones o confirmaciones explícitas.
- **Botón Atrás del sistema (`PopScope`):**
  - En pasos 2–5: retrocede al paso anterior (`_currentStep - 1`).
  - En paso 1: muestra confirmación `"¿Salir de la guía inicial?"` (en modo `isReopened: true`, hace `Navigator.pop()`).
- **Botón `Omitir` (pasos 1–4):** Pide confirmación breve (`"¿Omitir guía inicial? Podrás volver a abrirla cuando quieras desde Ajustes."`). Al confirmar, no guarda datos no confirmados del paso actual, actualiza flags y navega a `MainContainer` (o `Navigator.pop()` si `isReopened: true`).
- **Reapertura desde Ajustes:** En `lib/Screens/settings_screen.dart` se añade la opción `"Guía inicial"` que abre `OnboardingScreen(isReopened: true)`. Al finalizar en el Paso 5 (`"Volver a Ajustes"`), regresa a `SettingsScreen` sin duplicar datos.

---

## 3. Contenido Textual Propuesto (Español)

### Paso 1 — Bienvenida breve
- **Indicador:** `Paso 1 de 5`
- **Título:** `Bienvenido a Moneo`
- **Subtítulo:** `Tus datos se guardan en tu dispositivo. Moneo no requiere una cuenta en la nube para usar sus funciones principales.`
- **Tarjetas informativas:**
  1. `Organiza tus cuentas y categorías` — `Elige o crea solo las categorías y cuentas que realmente usas.`
  2. `Registra en segundos` — `Anota ingresos, gastos o transferencias desde el botón +.`
  3. `Almacenamiento en tu dispositivo` — `Tus movimientos y saldos se almacenan localmente en tu teléfono.`
- **CTAs:** Primaria: `Comenzar` | Secundaria (app bar): `Omitir`

### Paso 2 — Selección y creación de primeras categorías
- **Indicador:** `Paso 2 de 5`
- **Título:** `Elige tus primeras categorías`
- **Subtítulo:** `Selecciona las que uses o crea las tuyas. No agregamos categorías sin tu permiso.`
- **Controles:**
  - Selector segmentado (`MoneoSegmentedControl`): `Egresos` | `Ingresos`.
  - Listas predeterminadas seleccionables (**ninguna preseleccionada** por defecto):
    - *Egresos:* `Alimentación`, `Transporte`, `Vivienda`, `Servicios`, `Salud`, `Entretenimiento`, `Educación`, `Compras`.
    - *Ingresos:* `Salario`, `Freelance`, `Ventas`, `Inversiones`, `Reembolsos`, `Otros ingresos`.
  - Botón `+ Crear categoría propia` (abre modal con nombre, tipo Ingreso/Egreso, ícono de `lib/utils/app_icons.dart` y color de `AppColors`).
  - Resumen dinámico: `X de egresos · Y de ingresos seleccionadas`.
- **CTAs:** Primaria: `Guardar y continuar` (si 0 seleccionadas: `Continuar sin categorías`) | Secundaria: `Atrás`

### Paso 3 — Creación de la primera cuenta
- **Indicador:** `Paso 3 de 5`
- **Título:** `Crea tu primera cuenta`
- **Subtítulo:** `Puede ser efectivo, cuenta bancaria, billetera digital o tarjeta de crédito.`
- **Campos:**
  - Tipo de cuenta: `Efectivo`, `Cuenta bancaria`, `Billetera digital`, `Tarjeta de crédito`.
  - Nombre de cuenta (validación: no vacío, no contiene `" > "`, no duplicado).
  - Saldo inicial (`>= 0`, opcional con `0` por defecto).
- **CTAs:** Primaria: `Crear cuenta y continuar` | Secundaria: `Omitir y crear después` | `Atrás`

### Paso 4 — Primer ingreso o gasto real (opcional)
- **Indicador:** `Paso 4 de 5`
- **Título:** `Registra tu primer movimiento (opcional)`
- **Subtítulo:** `Registra tu primer ingreso o gasto real para verlo en tu balance, o continúa directo al resumen.`
- **Estados:**
  - Si falta cuenta o categoría del tipo elegido: tarjeta informativa `"Para registrar un movimiento primero necesitas al menos 1 cuenta y 1 categoría"` con acceso a crear o botón `Omitir este paso`.
  - Si existen cuenta y categoría: selector `Egreso` / `Ingreso`, monto (`> 0`), cuenta, categoría, fecha (hoy por defecto, formato completo `dd/MM/yyyy`) y nota opcional.
- **CTAs:** Primaria: `Guardar movimiento` | Secundaria: `Omitir este paso` | `Atrás`

### Paso 5 — Resumen final y regreso
- **Indicador:** `Paso 5 de 5`
- **Título:** `¡Todo listo!`
- **Subtítulo:** `Así quedó tu punto de partida en Moneo.`
- **Tarjetas de resumen:**
  - `Categorías configuradas:` `N ingresos · M egresos` (o `Ninguna aún — puedes crearlas en Categorías`).
  - `Cuentas activas:` lista breve con nombre y saldo (o `Ninguna aún — puedes crearlas en Cuentas`).
  - `Primer movimiento:` monto y tipo si se registró, o `Sin movimientos iniciales`.
- **Tip:** `Usa el botón + en Inicio para registrar movimientos cuando quieras.`
- **CTA:** `Ir a Inicio` (o `Volver a Ajustes` si `isReopened == true`)

---

## 4. Modelo de Estados y Reglas de Ciclo de Vida

Claves persistidas en `PrefsManager` (`SharedPreferences`):

1. `onboarding_completed` (`bool`, default `false`): `true` únicamente cuando el usuario finaliza el Paso 5, confirma `Omitir`, o se detecta como usuario existente.
2. `onboarding_skipped` (`bool`, default `false`): `true` cuando el usuario confirma `Omitir`. Si posteriormente abre la guía desde Ajustes y la finaliza en el Paso 5, pasa a `false`.
3. `onboarding_last_step` (`int`, default `0`, rango `0..4`): se actualiza al confirmar y avanzar en un paso; se reinicia a `0` al finalizar o al omitir.

### Reglas operativas
- **Primera apertura:** `onboarding_completed == false` y sin datos previos → abre `OnboardingScreen` en Paso 1 (`onboarding_last_step = 0`).
- **Omisión:** no guarda selecciones/formularios sin confirmar; marca `onboarding_skipped = true`, `onboarding_completed = true`, `onboarding_last_step = 0`; sigue disponible en Ajustes.
- **Abandono a mitad:** conserva solo los pasos ya confirmados explícitamente (cero datos parciales invisibles); `onboarding_completed` sigue en `false` y `onboarding_last_step` apunta al siguiente paso. Al reabrir la app, retoma en `onboarding_last_step` sin duplicar categorías, cuentas ni movimientos.
- **Usuario existente:** si `prefs.getBool('onboarding_completed') == null` y existe al menos 1 cuenta (`accounts` / `deleted_accounts`), 1 categoría (`income_categories` / `expense_categories`) o 1 transacción en Hive `'data'`, se marca `onboarding_completed = true` (`onboarding_skipped = false`) sin alterar ni borrar datos existentes. Puede abrir `"Guía inicial"` desde Ajustes cuando desee.
- **Paso 4 omitido:** si se omite el Paso 4, no queda ningún borrador ni movimiento pendiente o precargado.

---

## 5. Mejoras Incrementales de UI (Pantallas Existentes)

Sin rediseño completo, compatibles con `AppThemeData`, `MoneoHeaderBar` y `MoneoLayoutMetrics`:

1. **`AnnualProjectionScreen` (`lib/Screens/annual_projection_screen.dart`):**
   - Envolver `FloatingActionButton` con `Semantics(button: true, label: 'Nueva obligación anual')` + `tooltip`.
   - Agregar `SliverToBoxAdapter` con `MoneoLayoutMetrics.scrollBottomPadding(context, hasFab: true).bottom` para evitar solapamiento del FAB con la última tarjeta.
2. **`Statistics` (`lib/Screens/statistics.dart`):**
   - Eliminar truncamiento `date.substring(0, 6) + '...'` en `formatDate` y usar formato compacto legible (`DateFormat('dd MMM', 'es')` / `FittedBox(fit: BoxFit.scaleDown)`).
3. **`PendingTransactionsScreen` (`lib/features/notifications/presentation/screens/pending_transactions_screen.dart`):**
   - Reemplazar padding fijo `bottom: 24` por `MoneoLayoutMetrics.scrollBottomPadding(context, hasFab: false)` (respetando `viewPaddingOf(context).bottom`).
4. **`CategoriesScreen` (`lib/Screens/categories_screen.dart`):**
   - En `_buildCategoryList` cuando `categories.isEmpty`, añadir mensaje orientativo y CTA `"Crear categoría"` que invoque `_showCategoryDialog(type: type)`, sin sembrar categorías por defecto.
5. **Consistencia de formularios (`add.dart`, `add_expense.dart`, `transfer.dart`, `add_account_dialogs.dart`):**
   - Unificar mensajes de validación en español y canal de feedback (`AlertHelper.warning` + estado inline), preservando siempre los valores capturados ante error.

---

## 6. Criterios de Accesibilidad Verificables (Sin Promesas AAA)

- **Contraste:** Mínimo WCAG 2.1 AA (`>= 4.5:1` texto normal; `>= 3:1` texto grande/componentes) usando `context.appTheme` y `AppColors.getReadableColor`.
- **Targets táctiles:** Mínimo `48 x 48 dp` en botones, chips seleccionables y controles interactivos.
- **Semántica:** `Semantics(button: true, label: ..., identifier: ...)` y `tooltip` en FABs, chips (`selected`), selector de divisa y acciones del onboarding; `ExcludeSemantics` en páginas inactivas del `PageView`.
- **Escalado:** Pruebas automatizadas en `360x640` con `TextScaler.linear(1.35)` sin `RenderFlex overflow` ni texto cortado.

---

## 7. Casos de Prueba Requeridos

### Unitarios (`OnboardingService`)
- Storage vacío → `shouldShowOnboarding == true`, cero categorías/cuentas sembradas.
- Usuario existente (cuentas, categorías o Hive `'data'` no vacíos) → `shouldShowOnboarding == false`, marca `onboarding_completed = true` sin mutar datos.
- `skipOnboarding()` → `onboarding_completed = true`, `onboarding_skipped = true`, `onboarding_last_step = 0`.
- `advanceStep(n)` y reanudación → actualiza `onboarding_last_step` sin duplicar categorías/cuentas existentes.
- `completeOnboarding()` → `onboarding_completed = true`, `onboarding_skipped = false`, `onboarding_last_step = 0`.

### Widget (`OnboardingScreen` y mejoras UI)
- Flujo completo Pasos 1→5 con creación de categorías, cuenta y movimiento real.
- Omisión en Paso 1/3/4: sin datos no confirmados ni movimiento pendiente/precargado.
- Reapertura desde `SettingsScreen` (`isReopened: true`): no duplica datos y regresa a Ajustes.
- `360x640` con `TextScaler(1.35)`: cero `RenderFlex overflow`, targets `>= 48dp`, `Semantics` presentes en onboarding, `AnnualProjectionScreen` FAB, `CategoriesScreen` estado vacío, `Statistics` fechas completas y formularios preservando estado tras error.

### E2E Maestro (solo tras suite Flutter 100% verde)
- Flujo `.maestro/` ejecutado exclusivamente contra `com.example.finazaap.validation` usando datos **100% sintéticos** (sin datos reales ni modificación de la app original).
