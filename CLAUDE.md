# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

**Moneo / FinazaApp** is a 100% offline personal finance Flutter app with local AES-256 encryption, premium dark UI, and an on-device AI assistant (Google Gemma via `flutter_gemma`). Targets Android and iOS; also runnable on Web via Docker.

## Common commands

```bash
# Run on connected device
flutter run

# Run on web (needs Docker, starts Python model server on port 8081)
make web

# Static analysis
flutter analyze

# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Regenerate Hive adapters after modifying Add_data or Responsibility models
dart run build_runner build --delete-conflicting-outputs

# Build release APK (via Docker)
make apk
```

## Architecture

### Startup flow
`main.dart` → initializes in order: date formatting (es_ES), FlutterGemma, Hive + adapters, CurrencyHelper, EncryptionService, NotificationService → `FinazaApp` → `AuthSplashScreen` → PIN/biometric check (via `PinProvider`) → `MainContainer`.

### Navigation
`MainContainer` (`lib/Screens/main_container.dart`) uses `IndexedStack` with 5 tabs:
1. Home — account balances, recent transactions
2. ResponsibilitiesScreen — recurring obligations/bills
3. CategoriesScreen — transaction management per category
4. Statistics — charts and reports
5. SettingsScreen — currency, PIN, AI config, notifications

### Persistence layers
There are **two parallel persistence layers** for accounts, which must stay in sync:
- **SharedPreferences** (`'accounts'` key) — JSON list of account objects; the primary source for account balances
- **Hive boxes**: `data` (Box<Add_data>), `transactions_v2`, `accounts`, `accounts_v2`, `responsibilities` (Box<Responsibility>)

### Key models
Both Hive models require code generation (`build_runner`):
- `Add_data` (`lib/data/model/add_date.dart`, typeId: 1) — Transaction record. `IN` field = type (`'Income'`/`'Expenses'`/`'Transfer'`). Serialized into Hive box `'data'`.
- `Responsibility` (`lib/data/model/responsibility.dart`, typeId: 2) — Recurring obligation (bill, credit card, loan). Stored in Hive box `'responsibilities'`. After modifying either model, run `build_runner` to regenerate the `.g.dart` file.

### Key services
- `TransactionService` (`lib/data/transaction_service.dart`) — Singleton. All transaction creates/edits/deletes go through `processTransaction()`. It updates account balances in SharedPreferences and optionally records to Hive.
- `ResponsibilityService` (`lib/data/responsibility_service.dart`) — Static methods. Manages the `'responsibilities'` Hive box. Syncs with accounts when credit card transactions occur.
- `CreditCardCalculator` (`lib/data/credit_card_calculator.dart`) — **Single source of truth for credit card debt.** Derives balances dynamically by replaying all transactions in the `'data'` Hive box. The `cardBalance` stored on a `Responsibility` object is a legacy field and is NOT authoritative for `category == 'tarjeta'`.
- `EncryptionService` (`lib/core/security/encryption_service.dart`) — Singleton. AES-256 CBC; master key stored in `flutter_secure_storage`. Falls back to Base64 if uninitialized.
- `AiChatService` (`lib/services/ai_chat_service.dart`) — `ChangeNotifier`. Manages the Gemma model lifecycle. On Android/iOS the user must supply a model URL; the model is downloaded once by `flutter_gemma`. On Web, a Python server at port 8081 must serve the `.litertlm` file. A rule-based financial simulator serves as a fallback when the model is unavailable.

### Critical invariant for credit cards
When a transaction is recorded against a credit card account, `TransactionService` calls `ResponsibilityService.processDebtIncrease/processDebtPayment`. However, the displayed debt on the Responsibilities screen comes from `CreditCardCalculator`, which reads live from the `'data'` Hive box — not from `Responsibility.cardBalance`. Do not rely on `cardBalance` for credit cards.

### Theme
Dark-only theme. All colors are in `lib/themes/app_colors.dart` as `AppColors` constants. Primary background: `0xFF1F2639`. Accent: `0xFF52E2FF` (cyan). Never hardcode colors inline; use `AppColors`.

### AI model
Model file at `assets/models/gemma.litertlm` (not committed to git, ~2GB). The web dev workflow uses a local Python HTTP server to deliver it via streaming.
