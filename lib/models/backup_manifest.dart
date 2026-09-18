import '../core/constants/app_constants.dart';

enum BackupManifestKind { current, legacy }

class BackupManifest {
  const BackupManifest({
    required this.kind,
    required this.formatIdentifier,
    required this.formatVersion,
    required this.appName,
    required this.appVersion,
    required this.createdAt,
    required this.sourceClient,
    required this.platform,
  });

  final BackupManifestKind kind;
  final String formatIdentifier;
  final int formatVersion;
  final String appName;
  final String appVersion;
  final DateTime createdAt;
  final String sourceClient;
  final String platform;

  bool get isLegacy => kind == BackupManifestKind.legacy;

  factory BackupManifest.hanaBook({
    required DateTime createdAt,
    required String platform,
  }) {
    return BackupManifest(
      kind: BackupManifestKind.current,
      formatIdentifier: AppConstants.backupFormatIdentifier,
      formatVersion: AppConstants.backupFormatVersion,
      appName: AppConstants.displayName,
      appVersion: AppConstants.appVersion,
      createdAt: createdAt,
      sourceClient: 'flutter-local',
      platform: platform,
    );
  }

  factory BackupManifest.fromCurrentJson(Map<String, Object?> json) {
    return BackupManifest(
      kind: BackupManifestKind.current,
      formatIdentifier: _requiredString(json, 'formatIdentifier'),
      formatVersion: _requiredPositiveInt(json, 'formatVersion'),
      appName: _requiredString(json, 'appName'),
      appVersion: _requiredString(json, 'appVersion'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      sourceClient: _optionalString(json, 'sourceClient'),
      platform: _optionalString(json, 'platform'),
    );
  }

  factory BackupManifest.fromLegacyJson(Map<String, Object?> json) {
    return BackupManifest(
      kind: BackupManifestKind.legacy,
      formatIdentifier: 'legacy-flat-backup',
      formatVersion: _requiredPositiveInt(json, 'schemaVersion'),
      appName: _optionalString(json, 'app'),
      appVersion: '',
      createdAt: _requiredDateTime(json, 'exportedAt'),
      sourceClient: _optionalString(json, 'sourceClient'),
      platform: _optionalString(json, 'platform'),
    );
  }

  Map<String, Object?> toJson() {
    if (isLegacy) {
      return {
        'app': appName,
        'schemaVersion': formatVersion,
        'exportedAt': createdAt.toIso8601String(),
        'sourceClient': sourceClient,
        'platform': platform,
      };
    }
    return {
      'formatIdentifier': formatIdentifier,
      'formatVersion': formatVersion,
      'appName': appName,
      'appVersion': appVersion,
      'createdAt': createdAt.toIso8601String(),
      'sourceClient': sourceClient,
      'platform': platform,
    };
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('manifest.json 缺少有效的 $key。');
  }
  return value.trim();
}

String _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is String ? value.trim() : '';
}

int _requiredPositiveInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int || value <= 0) {
    throw FormatException('manifest.json 缺少有效的 $key。');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, Object?> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('manifest.json 的 $key 不是有效时间。');
  }
  return parsed;
}
