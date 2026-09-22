import 'dart:io';
import 'platform_helper.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  bool runInShell,
});

class PlatformHelperIo implements PlatformHelper {
  static final RegExp _validKeyPattern = RegExp(r'^[a-zA-Z0-9_\-]+$');

  final Directory Function()? _dirProvider;
  final ProcessRunner? _processRunner;
  final Directory? _oldCwdDirectory;
  final bool? _isWindowsOverride;

  PlatformHelperIo({
    Directory Function()? directoryProvider,
    this._processRunner,
    this._oldCwdDirectory,
    this._isWindowsOverride,
  }) : _dirProvider = directoryProvider;

  /// Validate key to prevent path traversal and illegal characters
  static void validateKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Khóa cấu hình (storage key) không được để trống.');
    }
    if (key.contains('..') || key.contains('/') || key.contains(r'\')) {
      throw ArgumentError('Phát hiện chuỗi path traversal trong storage key: $key');
    }
    if (!_validKeyPattern.hasMatch(key)) {
      throw ArgumentError('Storage key chứa ký tự không hợp lệ: $key');
    }
  }

  /// Resolve application config directory path based on environment variables
  static String resolveAppDirectoryPath({
    Map<String, String>? environment,
    bool? isWindows,
    bool? isMacOS,
    bool? isLinux,
  }) {
    final win = isWindows ?? Platform.isWindows;
    final mac = isMacOS ?? Platform.isMacOS;
    final lin = isLinux ?? Platform.isLinux;
    final env = environment ?? Platform.environment;

    if (win) {
      final appData = env['APPDATA'];
      if (appData != null && appData.trim().isNotEmpty) {
        return '$appData\\Birdle';
      }
      final localAppData = env['LOCALAPPDATA'];
      if (localAppData != null && localAppData.trim().isNotEmpty) {
        return '$localAppData\\Birdle';
      }
      final userProfile = env['USERPROFILE'];
      if (userProfile != null && userProfile.trim().isNotEmpty) {
        return '$userProfile\\AppData\\Roaming\\Birdle';
      }
      throw StateError('Không thể xác định thư mục người dùng an toàn trên Windows (%APPDATA% / %LOCALAPPDATA%).');
    } else if (mac) {
      final home = env['HOME'];
      if (home != null && home.trim().isNotEmpty) {
        return '$home/Library/Application Support/Birdle';
      }
      return '/tmp/Birdle';
    } else if (lin) {
      final xdg = env['XDG_CONFIG_HOME'];
      if (xdg != null && xdg.trim().isNotEmpty) {
        return '$xdg/Birdle';
      }
      final home = env['HOME'];
      if (home != null && home.trim().isNotEmpty) {
        return '$home/.config/Birdle';
      }
      return '/tmp/Birdle';
    } else {
      final home = env['HOME'];
      return home != null ? '$home/.birdle' : '/tmp/Birdle';
    }
  }

  /// Get or create the application config directory
  static Directory getAppDirectory({
    Map<String, String>? environment,
    bool? isWindows,
    bool? isMacOS,
    bool? isLinux,
  }) {
    final path = resolveAppDirectoryPath(
      environment: environment,
      isWindows: isWindows,
      isMacOS: isMacOS,
      isLinux: isLinux,
    );
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Validate that the URL is a safe HTTP or HTTPS URL
  static bool isValidWebUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    if (uri.host.isEmpty) return false;
    return true;
  }

  Directory _getAppDir() {
    final provider = _dirProvider;
    if (provider != null) {
      final dir = provider();
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir;
    }
    return getAppDirectory();
  }

  Future<ProcessResult> _runProcess(
    String executable,
    List<String> arguments, {
    bool runInShell = false,
  }) {
    final runner = _processRunner;
    if (runner != null) {
      return runner(executable, arguments, runInShell: runInShell);
    }
    return Process.run(executable, arguments, runInShell: runInShell);
  }

  @override
  Future<void> saveString(String key, String value) async {
    validateKey(key);
    final dir = _getAppDir();
    final file = File('${dir.path}${Platform.pathSeparator}$key.json');
    await file.writeAsString(value, flush: true);
  }

  @override
  Future<String?> getString(String key) async {
    validateKey(key);
    final dir = _getAppDir();
    final newFile = File('${dir.path}${Platform.pathSeparator}$key.json');

    // 1. Ưu tiên đọc từ thư mục mới (%APPDATA%\Birdle)
    if (await newFile.exists()) {
      try {
        return await newFile.readAsString();
      } catch (_) {
        return null;
      }
    }

    // 2. Migration an toàn từ CWD nếu vị trí mới chưa có
    final cwd = _oldCwdDirectory ?? Directory.current;
    final oldFile = File('${cwd.path}${Platform.pathSeparator}$key.json');

    if (await oldFile.exists()) {
      try {
        final oldData = await oldFile.readAsString();
        // Ghi sang vị trí mới
        await newFile.writeAsString(oldData, flush: true);
        // Giữ lại file cũ để tránh rủi ro mất dữ liệu
        return oldData;
      } catch (_) {
        // Nếu migration lỗi, vẫn trả về dữ liệu cũ để không làm gián đoạn
        try {
          return await oldFile.readAsString();
        } catch (_) {
          return null;
        }
      }
    }

    return null;
  }

  @override
  Future<void> openUrl(String url) async {
    final trimmed = url.trim();
    if (!isValidWebUrl(trimmed)) {
      throw ArgumentError('URL không hợp lệ hoặc scheme không được hỗ trợ (chỉ chấp nhận http/https): $url');
    }

    final isWin = _isWindowsOverride ?? Platform.isWindows;
    try {
      if (isWin) {
        // Trên Windows: Dùng rundll32 url.dll,FileProtocolHandler trực tiếp, KHÔNG qua cmd.exe hay shell
        await _runProcess(
          'rundll32',
          ['url.dll,FileProtocolHandler', trimmed],
          runInShell: false,
        );
      } else if (Platform.isMacOS) {
        await _runProcess('open', [trimmed], runInShell: false);
      } else {
        await _runProcess('xdg-open', [trimmed], runInShell: false);
      }
    } catch (_) {}
  }
}

PlatformHelper getPlatformHelper() => PlatformHelperIo();
