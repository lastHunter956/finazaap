import 'dart:io';
import 'package:finazaap/features/notifications/services/bank_whitelist_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T0.3 & T3.3 — Android Gradle, Manifest & Privacy Hardening', () {
    test('T0.3: android/build.gradle aligns Kotlin plugin to 2.1.0', () {
      final buildGradle = File('android/build.gradle').readAsStringSync();
      expect(buildGradle, contains("ext.kotlin_version = '2.1.0'"));
      expect(
        buildGradle,
        contains('force "org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0"'),
      );
      expect(buildGradle, isNot(contains('1.9.22')));
    });

    test('T3.3: AndroidManifest.xml disables backup and declares INTERNET', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:fullBackupContent="false"'));
      expect(
        manifest,
        contains('<uses-permission android:name="android.permission.INTERNET"/>'),
      );
    });

    test(
      'T3.3: android/app/build.gradle configures conditional release signing without signingConfigs.debug',
      () {
        final appGradle = File('android/app/build.gradle').readAsStringSync();
        expect(appGradle, contains('rootProject.file("key.properties")'));
        expect(appGradle, contains('signingConfigs'));
        expect(appGradle, contains('signingConfig = signingConfigs.release'));
        expect(appGradle, isNot(contains('signingConfigs.debug')));
        expect(appGradle, contains('applicationId = "com.example.finazaap"'));
      },
    );

    test('T3.3: MainActivity.kt supports configurable FLAG_SECURE', () {
      final mainActivity = File(
        'android/app/src/main/kotlin/com/example/finazaap/MainActivity.kt',
      ).readAsStringSync();
      expect(mainActivity, contains('WindowManager.LayoutParams.FLAG_SECURE'));
      expect(mainActivity, contains('com.example.finazaap/security'));
      expect(mainActivity, contains('syncSecureFlagFromPrefs'));
    });

    test(
      'T3.3: FinazaapWidgetProvider.kt removes financial Log.i and masks balances in privacy mode',
      () {
        final widgetProvider = File(
          'android/app/src/main/kotlin/com/example/finazaap/FinazaapWidgetProvider.kt',
        ).readAsStringSync();
        expect(widgetProvider, isNot(contains('Log.i(')));
        expect(widgetProvider, contains('isPrivacyActive'));
        expect(widgetProvider, contains('••••••'));
      },
    );

    test(
      'T3.3: home.dart _handleWidgetLaunch checks PIN before opening AddExpenseScreen',
      () {
        final homeDart = File('lib/Screens/home.dart').readAsStringSync();
        expect(homeDart, contains('Future<void> _handleWidgetLaunch'));
        expect(homeDart, contains("prefs.getBool('pin_enabled')"));
        expect(homeDart, contains('PinCodeScreen('));
        expect(homeDart, contains('PinMode.verify'));
      },
    );

    test(
      'T3.3: BankWhitelistService excludes simulated bank in release mode (!isDebug)',
      () {
        final releaseList =
            BankWhitelistService.buildDefaultBankList(isDebug: false);
        final releaseService = BankWhitelistService(initialBanks: releaseList);

        expect(
          releaseList.any((b) => b.packageName == 'com.moneo.simulated.bank'),
          isFalse,
        );
        expect(
          releaseService.isWhitelisted('com.moneo.simulated.bank'),
          isFalse,
        );
        expect(
          releaseService.isWhitelisted('com.bancolombia.personas'),
          isTrue,
        );

        final debugList =
            BankWhitelistService.buildDefaultBankList(isDebug: true);
        expect(
          debugList.any((b) => b.packageName == 'com.moneo.simulated.bank'),
          isTrue,
        );
      },
    );
  });
}
