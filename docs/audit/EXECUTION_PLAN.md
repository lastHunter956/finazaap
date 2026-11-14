# Plan de Ejecución por Olas (`docs/audit/EXECUTION_PLAN.md`)

> **Regla absoluta:** Ninguna pareja de tareas en paralelo puede tocar el mismo archivo. Toda tarea sobre archivos protegidos, saldos, tarjetas, cifrado, migraciones, firma o `applicationId` requiere aprobación explícita del usuario y revisión humana.

---

## Grafo de Olas Secuenciales

```
[Ola 0: Diagnóstico + Baseline]  (bloquea todo)
         │
         ▼
[Ola 1: Contabilidad Crítica]   (bloquea Olas 2, 3 y 4)
         │
         ▼
[Ola 2: Modelo IA On-Device]    (requiere D1, D2)
         │
         ▼
[Ola 3: Seguridad Integral]     (requiere D3, D4, D5, D6, D7)
         │
         ▼
[Ola 4: Fluidez y Performance]  (al final, sobre código correcto y seguro)
```

---

## Detalle por Ola y Reglas de Paralelismo

### Ola 0 — Diagnóstico de solo lectura y pruebas de reproducción
| Tarea | Modelo | Paralelizable con | Motivo |
|---|---|---|---|
| `T0.1` | Ligero | `T0.2` | `T0.1` solo crea `test/audit/accounting_repro_test.dart`; `T0.2` solo lee/ejecuta checks en Docker. |
| `T0.2` | Ligero | `T0.1` | Cero archivos compartidos. |

### Ola 1 — Errores contables críticos *(requiere aprobación para `T1.3a` y `T1.3b`)*
| Tarea | Modelo | Archivos principales | Paralelizable | Motivo |
|---|---|---|---|---|
| `T1.1` | Ligero | `currency_helper.dart`, `account_item.dart` | No con `T1.3c` | `T1.3c` usa el `AccountItem` canónico limpio de `T1.1` (`add_expense.dart`, `transfer.dart`, `statistics.dart`). |
| `T1.2` | Fuerte | `responsibility_service.dart`, `responsibility.dart` | Sí con `T1.1` | Archivos 100% disjuntos. |
| `T1.3a` | Fuerte | `lib/data/transaction_service.dart` (**PROTEGIDO**) | **NO** | Archivo protegido; `T1.3c` depende de sus firmas corregidas. |
| `T1.3b` | Fuerte | `lib/data/credit_card_calculator.dart` (**PROTEGIDO**) | Sí con `T1.3a` (tras aprobación) | Archivos disjuntos, pero ambos son críticos y conviene revisión secuencial. |
| `T1.3c` | Fuerte | Formularios y pantallas contables (`add_expense.dart`, `add.dart`, `transfer.dart`, `daily_transactions.dart`, `responsibilities_screen.dart`, `annual_projection_screen.dart`, `home.dart`, `selecctaccount.dart`, `edit_account_dialogs.dart`, `add_account_dialogs.dart`) | **NO** | Depende de `T1.1`, `T1.2`, `T1.3a`, `T1.3b`. |
| `T1.4` | Fuerte | `notification_parser.dart`, `transaction_classifier.dart`, `notification_pipeline_service.dart`, `pending_transactions_notifier.dart`, `pending_transactions_screen.dart`, `notification_event.dart`, `category_service.dart` | Sí con `T1.3b` | No toca formularios ni `transaction_service.dart` (excepto si se coordina la firma de `ai_chat_service.dart:acceptTransactionSuggestion`, que puede quedar en `T1.4` siempre que Ola 2 aún no inicie). |

### Ola 2 — Modelo IA *(requiere D1 y D2)*
| Tarea | Modelo | Archivos principales | Paralelizable | Motivo |
|---|---|---|---|---|
| `T2.1` | Fuerte | `ai_chat_service.dart`, `gemma_classifier_adapter.dart` | **NO** | `T2.2` consume métodos/propiedades de `ai_chat_service.dart` (progreso, archivo local). |
| `T2.2` | Ligero | `device_capability_service.dart`, `MainActivity.kt`, `ai_chat_screen.dart`, `AndroidManifest.xml` (**PROTEGIDO** si D2=A) | **NO** | Depende de `T2.1`. |

### Ola 3 — Seguridad *(requiere D3–D7 y aprobación para archivos protegidos)*
| Tarea | Modelo | Archivos principales | Paralelizable | Motivo |
|---|---|---|---|---|
| `T3.1` | Fuerte | `encryption_service.dart` (**PROTEGIDO**), `main.dart`, `responsibility_service.dart`, `transaction_service.dart` (**PROTEGIDO**), `data_management_service.dart`, `encrypted_hive_datasource.dart`, `secure_preferences_datasource.dart`, `MoneoNotificationListenerService.kt` | **NO** | Toca el núcleo de persistencia y arranque. |
| `T3.2` | Fuerte | `pin_provider.dart`, `pin_code_screen.dart`, `auth_splash_screen.dart`, `main_container.dart` | **NO** (después de `T3.1`) | Evita conflictos en `main.dart` / `FlutterSecureStorage`. |
| `T3.3` | Fuerte | `build.gradle` (**PROTEGIDO**), `AndroidManifest.xml` (**PROTEGIDO**), `MainActivity.kt`, `FinazaapWidgetProvider.kt`, `home.dart`, `bank_whitelist_service.dart` | Sí con `T3.4` | Archivos 100% disjuntos respecto a `T3.4`. |
| `T3.4` | Ligero | `transaction_classifier.dart`, `notification_parser.dart`, `ai_chat_screen.dart`, `ai_chat_service.dart`, `.agents/hooks/check_protected_files.py`, `.gitignore` | Sí con `T3.3` | Archivos 100% disjuntos respecto a `T3.3`. |

### Ola 4 — Fluidez y Performance
| Tarea | Modelo | Archivos principales | Paralelizable | Motivo |
|---|---|---|---|---|
| `T4.1` | Ligero | `main.dart`, `main_container.dart`, `categories_screen.dart` | **NO** | Base de ciclo de vida para `Home` y `Statistics`. |
| `T4.2` | Fuerte | `home.dart`, `statistics.dart`, `total_balance_widget.dart` | Sí con `T4.3` | Archivos disjuntos (`T4.3` no toca `home.dart`, `statistics.dart` ni `total_balance_widget.dart`). |
| `T4.3` | Ligero | `floating_action_menu_screen.dart`, `selecctaccount.dart`, `responsibility_list_item.dart`, `responsibilities_screen.dart`, `add.dart`, `transfer.dart`, `ai_chat_screen.dart`, `pubspec.yaml` | Sí con `T4.2` | Archivos disjuntos respecto a `T4.2`. |
