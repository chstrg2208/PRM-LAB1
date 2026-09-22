import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdle/services/platform_helper_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempAppDir;
  late Directory tempCwdDir;

  setUp(() {
    tempAppDir = Directory.systemTemp.createTempSync('birdle_app_test_');
    tempCwdDir = Directory.systemTemp.createTempSync('birdle_cwd_test_');
  });

  tearDown(() {
    try {
      if (tempAppDir.existsSync()) tempAppDir.deleteSync(recursive: true);
    } catch (_) {}
    try {
      if (tempCwdDir.existsSync()) tempCwdDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('BK-04: Lưu/đọc cấu hình và Thư mục an toàn ngoài CWD', () {
    test('1.1. Đường dẫn cấu hình Windows ưu tiên %APPDATA%\\Birdle, không fallback về CWD', () {
      final envAppData = {
        'APPDATA': r'C:\Users\Teacher\AppData\Roaming',
        'LOCALAPPDATA': r'C:\Users\Teacher\AppData\Local',
      };
      final resolved = PlatformHelperIo.resolveAppDirectoryPath(
        environment: envAppData,
        isWindows: true,
      );
      expect(resolved, r'C:\Users\Teacher\AppData\Roaming\Birdle');
      expect(resolved.toLowerCase(), isNot(contains(Directory.current.path.toLowerCase())));

      // Fallback sang LOCALAPPDATA nếu APPDATA rỗng/không có
      final envLocalAppData = {
        'LOCALAPPDATA': r'C:\Users\Teacher\AppData\Local',
      };
      final resolvedLocal = PlatformHelperIo.resolveAppDirectoryPath(
        environment: envLocalAppData,
        isWindows: true,
      );
      expect(resolvedLocal, r'C:\Users\Teacher\AppData\Local\Birdle');

      // Fallback sang USERPROFILE nếu cả hai không có
      final envUserProfile = {
        'USERPROFILE': r'C:\Users\Teacher',
      };
      final resolvedProfile = PlatformHelperIo.resolveAppDirectoryPath(
        environment: envUserProfile,
        isWindows: true,
      );
      expect(resolvedProfile, r'C:\Users\Teacher\AppData\Roaming\Birdle');

      // Lỗi khi không có bất kỳ biến môi trường nào (không fallback CWD)
      expect(
        () => PlatformHelperIo.resolveAppDirectoryPath(
          environment: {},
          isWindows: true,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('1.2. Tự động tạo thư mục và ghi/đọc cấu hình thành công ngoài CWD', () async {
      final nestedAppDir = Directory('${tempAppDir.path}${Platform.pathSeparator}Nested${Platform.pathSeparator}Birdle');
      expect(nestedAppDir.existsSync(), isFalse);

      final helper = PlatformHelperIo(
        directoryProvider: () => nestedAppDir,
        oldCwdDirectory: tempCwdDir,
      );

      const testKey = 'test_settings';
      const testJson = '{"url":"https://example.com","class":"SE1801"}';

      await helper.saveString(testKey, testJson);

      // Thư mục phải được tạo tự động
      expect(nestedAppDir.existsSync(), isTrue);

      // File được tạo dưới AppData directory
      final expectedFile = File('${nestedAppDir.path}${Platform.pathSeparator}$testKey.json');
      expect(expectedFile.existsSync(), isTrue);

      // Tuyệt đối không có file nào được ghi vào CWD
      final cwdFile = File('${tempCwdDir.path}${Platform.pathSeparator}$testKey.json');
      expect(cwdFile.existsSync(), isFalse);
      final realCwdFile = File('${Directory.current.path}${Platform.pathSeparator}$testKey.json');
      expect(realCwdFile.existsSync(), isFalse);

      // Đọc lại trả về chính xác nội dung ban đầu
      final readValue = await helper.getString(testKey);
      expect(readValue, testJson);
    });
  });

  group('BK-04: Key an toàn (Chống path traversal và ký tự nguy hiểm)', () {
    test('2.1. Key hợp lệ lưu thành công đúng filename', () async {
      final helper = PlatformHelperIo(
        directoryProvider: () => tempAppDir,
        oldCwdDirectory: tempCwdDir,
      );

      await helper.saveString('fap_attendance_settings', '{"ok":true}');
      final file = File('${tempAppDir.path}${Platform.pathSeparator}fap_attendance_settings.json');
      expect(file.existsSync(), isTrue);
    });

    test('2.2. Key chứa traversal (../, ..\\) hoặc ký tự nguy hiểm bị từ chối', () async {
      final helper = PlatformHelperIo(
        directoryProvider: () => tempAppDir,
        oldCwdDirectory: tempCwdDir,
      );

      final invalidKeys = [
        '',
        '   ',
        '../traversal',
        r'..\traversal',
        'sub/dir',
        r'sub\dir',
        'key:name',
        'key*wildcard',
        'key?question',
        'key|pipe',
        'key"quote',
        'key<angle>',
      ];

      for (final badKey in invalidKeys) {
        expect(
          () => PlatformHelperIo.validateKey(badKey),
          throwsA(isA<ArgumentError>()),
          reason: 'Key "$badKey" phải bị từ chối bởi validateKey',
        );

        expect(
          () async => await helper.saveString(badKey, 'val'),
          throwsA(isA<ArgumentError>()),
          reason: 'Key "$badKey" phải bị từ chối bởi saveString',
        );

        expect(
          () async => await helper.getString(badKey),
          throwsA(isA<ArgumentError>()),
          reason: 'Key "$badKey" phải bị từ chối bởi getString',
        );
      }
    });
  });

  group('BK-04: Migration tương thích cấu hình cũ từ CWD', () {
    test('3.1. Có file cũ tại CWD và chưa có file mới: migrate an toàn sang AppData và bảo toàn file cũ', () async {
      const key = 'fap_attendance_settings';
      const oldConfigData = '{"source":"old_cwd_config","val":42}';

      // Tạo file cũ tại CWD giả lập
      final oldFile = File('${tempCwdDir.path}${Platform.pathSeparator}$key.json');
      oldFile.writeAsStringSync(oldConfigData);
      expect(oldFile.existsSync(), isTrue);

      final helper = PlatformHelperIo(
        directoryProvider: () => tempAppDir,
        oldCwdDirectory: tempCwdDir,
      );

      final newFile = File('${tempAppDir.path}${Platform.pathSeparator}$key.json');
      expect(newFile.existsSync(), isFalse);

      // Gọi getString lần đầu -> tự động migrate
      final loaded = await helper.getString(key);
      expect(loaded, oldConfigData);

      // File mới tại AppData đã được tạo với đúng nội dung
      expect(newFile.existsSync(), isTrue);
      expect(newFile.readAsStringSync(), oldConfigData);

      // File cũ vẫn được bảo toàn (không bị xóa mất) để phòng ngừa rủi ro
      expect(oldFile.existsSync(), isTrue);
    });

    test('3.2. Khi đã có file mới tại AppData: luôn ưu tiên file mới', () async {
      const key = 'fap_attendance_settings';
      const oldConfigData = '{"version":"old"}';
      const newConfigData = '{"version":"new_priority"}';

      final oldFile = File('${tempCwdDir.path}${Platform.pathSeparator}$key.json');
      oldFile.writeAsStringSync(oldConfigData);

      final newFile = File('${tempAppDir.path}${Platform.pathSeparator}$key.json');
      newFile.writeAsStringSync(newConfigData);

      final helper = PlatformHelperIo(
        directoryProvider: () => tempAppDir,
        oldCwdDirectory: tempCwdDir,
      );

      final loaded = await helper.getString(key);
      expect(loaded, newConfigData);
    });
  });

  group('BK-04: Mở URL an toàn không qua shell', () {
    test('4.1. URL HTTPS chứa & được truyền nguyên vẹn, không dùng cmd /c start', () async {
      String? launchedExecutable;
      List<String>? launchedArguments;
      bool? launchedRunInShell;

      final helper = PlatformHelperIo(
        isWindowsOverride: true,
        processRunner: (executable, arguments, {bool runInShell = false}) async {
          launchedExecutable = executable;
          launchedArguments = arguments;
          launchedRunInShell = runInShell;
          return ProcessResult(0, 0, '', '');
        },
      );

      const complexUrl = 'https://script.google.com/macros/s/example/exec?action=test&class=SE1801&slot=2';
      await helper.openUrl(complexUrl);

      // Xác nhận trên Windows dùng rundll32, KHÔNG dùng cmd
      expect(launchedExecutable, 'rundll32');
      expect(launchedExecutable, isNot('cmd'));
      expect(launchedRunInShell, isFalse);

      // Xác nhận arguments không chứa /c hay start hay nối chuỗi shell
      expect(launchedArguments, isNotNull);
      expect(launchedArguments, contains('url.dll,FileProtocolHandler'));
      expect(launchedArguments, isNot(contains('/c')));
      expect(launchedArguments, isNot(contains('start')));

      // Xác nhận URL được truyền nguyên vẹn như 1 argument, không bị cắt tại dấu &
      expect(launchedArguments![1], complexUrl);
      expect(launchedArguments![1], contains('&class=SE1801'));
      expect(launchedArguments![1], contains('&slot=2'));
    });

    test('4.2. Scheme không an toàn (javascript:, file:) hoặc URL không hợp lệ bị từ chối, không spawn process', () async {
      int processCallCount = 0;

      final helper = PlatformHelperIo(
        isWindowsOverride: true,
        processRunner: (executable, arguments, {bool runInShell = false}) async {
          processCallCount++;
          return ProcessResult(0, 0, '', '');
        },
      );

      final unsafeUrls = [
        'javascript:alert("hacked")',
        'file:///C:/Windows/System32/calc.exe',
        'data:text/html,<script>alert(1)</script>',
        'not_a_valid_url',
        'ftp://example.com/file.zip',
        '',
        '   ',
      ];

      for (final unsafeUrl in unsafeUrls) {
        expect(
          () async => await helper.openUrl(unsafeUrl),
          throwsA(isA<ArgumentError>()),
          reason: 'URL "$unsafeUrl" phải bị từ chối',
        );
      }

      // Process runner tuyệt đối không được gọi lần nào
      expect(processCallCount, 0);
    });
  });
}
