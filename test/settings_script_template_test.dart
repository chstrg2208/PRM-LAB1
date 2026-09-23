import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/screens/settings_view.dart';
import 'package:birdle/widgets/apps_script_template_card.dart';
import 'package:birdle/widgets/birdle_components.dart';

class FakeAssetBundle extends CachingAssetBundle {
  final Map<String, String> assets;
  final Duration? delay;
  final bool shouldThrow;

  FakeAssetBundle({
    this.assets = const {},
    this.delay,
    this.shouldThrow = false,
  });

  @override
  Future<ByteData> load(String key) async {
    if (delay != null) {
      await Future.delayed(delay!);
    }
    if (shouldThrow || !assets.containsKey(key)) {
      throw FlutterError('Asset not found: $key');
    }
    final bytes = utf8.encode(assets[key]!);
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BK-11: Single Source of Truth & Asset Integrity Tests', () {
    test('1. google-apps-script/Code.gs exists and contains production GAS backend implementation', () {
      final file = File('google-apps-script/Code.gs');
      expect(file.existsSync(), isTrue, reason: 'google-apps-script/Code.gs must exist in repo root');

      final content = file.readAsStringSync();
      expect(content.contains('SpreadsheetApp'), isTrue);
      expect(content.contains('saveAttendance'), isTrue);
      expect(content.contains('LockService'), isTrue);
      expect(content.contains('getStudents'), isTrue);
      expect(content.contains('syncStudents'), isTrue);
      expect(content.contains('getAttendanceOverview'), isTrue);
    });

    test('2. SettingsView does not contain hardcoded sampleScript constant', () {
      final file = File('lib/screens/settings_view.dart');
      final content = file.readAsStringSync();
      expect(content.contains('static const String sampleScript'), isFalse,
          reason: 'sampleScript constant must be completely removed');
      expect(content.contains('sampleScript ='), isFalse);
    });
  });

  group('BK-11: AppsScriptTemplateCard Widget Tests', () {
    testWidgets('3. Loaded state: Displays script content and enables copy button with SnackBar feedback',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const mockScript = '// PRODUCTION SCRIPT\nfunction doGet(e) { return "ok"; }';
      final fakeBundle = FakeAssetBundle(assets: {
        'google-apps-script/Code.gs': mockScript,
      });

      String? copiedClipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedClipboardText = (methodCall.arguments as Map)['text'] as String?;
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppsScriptTemplateCard(bundle: fakeBundle),
            ),
          ),
        ),
      );

      // Wait for asset loading to finish
      await tester.pumpAndSettle();

      // Verify script is displayed inside SelectableText
      expect(find.text(mockScript), findsOneWidget);
      expect(find.text('Mã Nguồn Backend Google Apps Script (Code.gs)'), findsOneWidget);

      // Verify Copy button is enabled
      final copyButtonFinder = find.widgetWithText(BirdleSecondaryButton, 'Sao chép mã');
      expect(copyButtonFinder, findsOneWidget);
      final buttonWidget = tester.widget<BirdleSecondaryButton>(copyButtonFinder);
      expect(buttonWidget.onPressed, isNotNull);

      // Tap Copy button
      await tester.tap(copyButtonFinder);
      await tester.pump();

      // Verify clipboard content and SnackBar
      expect(copiedClipboardText, equals(mockScript));
      expect(find.text('✓ Đã sao chép toàn bộ mã nguồn Google Apps Script!'), findsOneWidget);
    });

    testWidgets('4. Loading state: Shows loading spinner and disables copy button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const mockScript = '// PRODUCTION SCRIPT';
      final fakeBundle = FakeAssetBundle(
        assets: {'google-apps-script/Code.gs': mockScript},
        delay: const Duration(seconds: 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppsScriptTemplateCard(bundle: fakeBundle),
            ),
          ),
        ),
      );

      // Initial pump without advancing time
      await tester.pump();

      // Verify loading state UI
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Đang tải mã nguồn Google Apps Script...'), findsOneWidget);

      // Verify copy button is in loading / disabled state
      final loadingButtonFinder = find.widgetWithText(BirdleSecondaryButton, 'Đang tải...');
      expect(loadingButtonFinder, findsOneWidget);
      final loadingButton = tester.widget<BirdleSecondaryButton>(loadingButtonFinder);
      expect(loadingButton.onPressed, isNull);

      // Advance time to complete loading
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Đang tải mã nguồn Google Apps Script...'), findsNothing);
      expect(find.text(mockScript), findsOneWidget);
    });

    testWidgets('5. Error state: Displays error message, hides copy, and provides retry button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final failingBundle = FakeAssetBundle(
        assets: {'google-apps-script/Code.gs': '// RECOVERED SCRIPT'},
        shouldThrow: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppsScriptTemplateCard(bundle: failingBundle),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify error state
      expect(find.text('Không thể tải mã nguồn Google Apps Script'), findsOneWidget);
      expect(find.widgetWithText(BirdleSecondaryButton, 'Sao chép mã'), findsNothing);
      expect(find.widgetWithText(BirdleSecondaryButton, 'Thử lại'), findsOneWidget);

      // Create a working bundle for retry test
      final workingBundle = FakeAssetBundle(
        assets: {'google-apps-script/Code.gs': '// RECOVERED SCRIPT'},
        shouldThrow: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppsScriptTemplateCard(bundle: workingBundle),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('// RECOVERED SCRIPT'), findsOneWidget);
      expect(find.widgetWithText(BirdleSecondaryButton, 'Sao chép mã'), findsOneWidget);
    });

    testWidgets('6. SettingsView integration: Renders AppsScriptTemplateCard seamlessly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const mockScript = '// INTEGRATED SCRIPT CONTENT';
      final fakeBundle = FakeAssetBundle(assets: {
        'google-apps-script/Code.gs': mockScript,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsView(
              initialSheetUrl: 'https://script.google.com/macros/s/test/exec',
              onSaveSheetUrl: (_) {},
              scriptAssetBundle: fakeBundle,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Section 3 template card is present and displays the script
      expect(find.byType(AppsScriptTemplateCard), findsOneWidget);
      expect(find.text(mockScript), findsOneWidget);
      expect(find.text('Mã Nguồn Backend Google Apps Script (Code.gs)'), findsOneWidget);
    });
  });
}
