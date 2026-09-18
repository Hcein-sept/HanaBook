import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';
import '../models/rating_presentation_config.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final ratingPresentationConfigProvider =
    FutureProvider<RatingPresentationConfig>((ref) {
  return ref.watch(settingsServiceProvider).readRatingPresentationConfig();
});

class SettingsService {
  SettingsService({Future<File> Function()? settingsFile})
      : _settingsFileOverride = settingsFile;

  final Future<File> Function()? _settingsFileOverride;
  Future<void> _settingsWriteQueue = Future<void>.value();

  static const _ratingPresentationConfigKey = 'ratingPresentationConfig';
  static const _ratingDefaultsInitializedKey =
      'ratingPresentationDefaultsInitialized';

  Future<String?> readTmdbToken() async {
    final settings = await _readSettings();
    final token = settings['tmdbToken'];
    if (token is! String) {
      return null;
    }
    final trimmed = token.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> saveTmdbToken(String token) async {
    await _updateSettings((settings) {
      final trimmed = token.trim();
      if (trimmed.isEmpty) {
        settings.remove('tmdbToken');
      } else {
        settings['tmdbToken'] = trimmed;
      }
    });
  }

  Future<RatingPresentationConfig> readRatingPresentationConfig() async {
    final settings = await _readSettings();
    if (settings[_ratingDefaultsInitializedKey] != true) {
      await _updateSettings((latestSettings) {
        if (latestSettings[_ratingDefaultsInitializedKey] == true) return;

        final current = RatingPresentationConfig.fromJson(
          latestSettings[_ratingPresentationConfigKey],
        );
        if (current.colorRules.isEmpty) {
          latestSettings[_ratingPresentationConfigKey] =
              RatingPresentationConfig(
            colorRules: RatingPresentationConfig.hanaBookDefaults.colorRules,
            tags: current.tags,
            style: current.style,
          ).toJson();
        }
        latestSettings[_ratingDefaultsInitializedKey] = true;
      });

      final initializedSettings = await _readSettings();
      return RatingPresentationConfig.fromJson(
        initializedSettings[_ratingPresentationConfigKey],
      );
    }
    return RatingPresentationConfig.fromJson(
      settings[_ratingPresentationConfigKey],
    );
  }

  Future<void> saveRatingPresentationConfig(
    RatingPresentationConfig config,
  ) async {
    await _updateSettings((settings) {
      settings[_ratingPresentationConfigKey] = config.toJson();
      settings[_ratingDefaultsInitializedKey] = true;
    });
  }

  Future<void> _updateSettings(
    void Function(Map<String, Object?> settings) update,
  ) {
    final operation = _settingsWriteQueue.then((_) async {
      final settings = await _readSettings();
      update(settings);
      await _writeSettings(settings);
    });
    _settingsWriteQueue = operation.catchError((_) {});
    return operation;
  }

  Future<Map<String, Object?>> _readSettings() async {
    final file = await _settingsFile();
    if (!file.existsSync()) {
      return {};
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return Map<String, Object?>.from(decoded);
      }
    } catch (_) {
      return {};
    }
    return {};
  }

  Future<void> _writeSettings(Map<String, Object?> settings) async {
    final file = await _settingsFile();
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(settings));
  }

  Future<File> _settingsFile() async {
    final override = _settingsFileOverride;
    if (override != null) {
      return override();
    }
    final documentsDir = await getApplicationDocumentsDirectory();
    return File(
      p.join(documentsDir.path, AppConstants.dataRootName, 'settings.json'),
    );
  }
}
