import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recallio/models/rating_presentation_config.dart';
import 'package:recallio/services/settings_service.dart';

void main() {
  late Directory tempDirectory;
  late File settingsFile;
  late SettingsService service;

  setUp(() {
    tempDirectory = Directory.systemTemp.createTempSync('recallio_settings_');
    settingsFile = File('${tempDirectory.path}/nested/settings.json');
    service = SettingsService(settingsFile: () async => settingsFile);
  });

  tearDown(() {
    if (tempDirectory.existsSync()) {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  test('missing config initializes and persists HanaBook color defaults',
      () async {
    final config = await service.readRatingPresentationConfig();

    expect(config.colorRules, hasLength(5));
    expect(config.tags, isEmpty);
    expect(
      config.colorRules.map((rule) => rule.colorHex),
      ['#7B737D', '#75879A', '#70968E', '#9477A5', '#D0A64B'],
    );

    final raw = jsonDecode(await settingsFile.readAsString()) as Map;
    expect(raw['ratingPresentationConfig'], config.toJson());
    expect(raw['ratingPresentationDefaultsInitialized'], isTrue);
  });

  test('old settings without rating config preserve data and gain defaults',
      () async {
    settingsFile.parent.createSync(recursive: true);
    await settingsFile.writeAsString(jsonEncode({'tmdbToken': 'old-token'}));

    final config = await service.readRatingPresentationConfig();

    expect(config.colorRules, hasLength(5));
    expect(config.tags, isEmpty);
    expect(await service.readTmdbToken(), 'old-token');

    final raw = jsonDecode(await settingsFile.readAsString()) as Map;
    expect(raw['tmdbToken'], 'old-token');
    expect(raw['ratingPresentationConfig'], isA<Map>());
  });

  test('an explicitly saved empty config never restores defaults', () async {
    await service.saveRatingPresentationConfig(RatingPresentationConfig.empty);

    expect((await service.readRatingPresentationConfig()).isEmpty, isTrue);
    expect((await service.readRatingPresentationConfig()).isEmpty, isTrue);

    final raw = jsonDecode(await settingsFile.readAsString()) as Map;
    final stored = raw['ratingPresentationConfig'] as Map;
    expect(stored['colorRules'], isEmpty);
    expect(stored['tags'], isEmpty);
  });

  test('first read never overwrites a concurrent explicit empty save',
      () async {
    await Future.wait([
      service.readRatingPresentationConfig(),
      service.saveRatingPresentationConfig(RatingPresentationConfig.empty),
    ]);

    expect((await service.readRatingPresentationConfig()).isEmpty, isTrue);
  });

  test('legacy tags-only config keeps tags and gains default colors once',
      () async {
    const tagsOnly = RatingPresentationConfig(
      tags: [
        ScoreTagRule(
          id: 'legacy-tag',
          name: '用户标签',
          colorHex: '#123456',
          condition: ScoreTagCondition.gte,
          threshold: 7,
          enabled: true,
          order: 0,
        ),
      ],
    );
    settingsFile.parent.createSync(recursive: true);
    await settingsFile.writeAsString(
      jsonEncode({'ratingPresentationConfig': tagsOnly.toJson()}),
    );

    final config = await service.readRatingPresentationConfig();

    expect(config.colorRules, hasLength(5));
    expect(config.tags.single.id, 'legacy-tag');

    final raw = jsonDecode(await settingsFile.readAsString()) as Map;
    expect(raw['ratingPresentationDefaultsInitialized'], isTrue);
  });

  test('legacy explicitly empty config gains defaults once', () async {
    settingsFile.parent.createSync(recursive: true);
    await settingsFile.writeAsString(
      jsonEncode({
        'ratingPresentationConfig': RatingPresentationConfig.empty.toJson(),
      }),
    );

    final config = await service.readRatingPresentationConfig();

    expect(config.colorRules, hasLength(5));
    expect(config.tags, isEmpty);
  });

  test('initialized empty config stays empty after user clears all rules',
      () async {
    settingsFile.parent.createSync(recursive: true);
    await settingsFile.writeAsString(
      jsonEncode({
        'ratingPresentationConfig': RatingPresentationConfig.empty.toJson(),
        'ratingPresentationDefaultsInitialized': true,
      }),
    );

    expect((await service.readRatingPresentationConfig()).isEmpty, isTrue);
  });

  test('legacy custom color rules are preserved instead of replaced', () async {
    const customConfig = RatingPresentationConfig(
      colorRules: [
        ScoreColorRule(
          id: 'legacy-custom',
          minScore: 0,
          maxScore: 10,
          colorHex: '#123456',
          enabled: true,
          order: 0,
        ),
      ],
    );
    settingsFile.parent.createSync(recursive: true);
    await settingsFile.writeAsString(
      jsonEncode({'ratingPresentationConfig': customConfig.toJson()}),
    );

    final config = await service.readRatingPresentationConfig();

    expect(config.colorRules, hasLength(1));
    expect(config.colorRules.single.id, 'legacy-custom');
    expect(config.colorRules.single.colorHex, '#123456');

    final raw = jsonDecode(await settingsFile.readAsString()) as Map;
    expect(raw['ratingPresentationDefaultsInitialized'], isTrue);
  });

  test('saves presentation config while preserving unrelated settings',
      () async {
    await service.saveTmdbToken('existing-token');
    const config = RatingPresentationConfig(
      colorRules: [
        ScoreColorRule(
          id: 'user-color',
          minScore: 1,
          maxScore: 3.5,
          colorHex: '#123456',
          enabled: true,
          order: 7,
        ),
      ],
      tags: [
        ScoreTagRule(
          id: 'user-tag',
          name: '自定义',
          colorHex: '#654321',
          condition: ScoreTagCondition.lte,
          threshold: 4,
          enabled: true,
          order: 9,
        ),
      ],
      style: RatingPresentationStyle(
        unmatchedColorHex: '#ABCDEF',
        inactiveStarColorHex: '#102030',
      ),
    );

    await service.saveRatingPresentationConfig(config);

    final restored = await service.readRatingPresentationConfig();
    expect(await service.readTmdbToken(), 'existing-token');
    expect(restored.colorRules.single.id, 'user-color');
    expect(restored.tags.single.name, '自定义');
    expect(restored.style.unmatchedColorHex, '#ABCDEF');

    final raw = jsonDecode(await settingsFile.readAsString()) as Map;
    expect(raw['tmdbToken'], 'existing-token');
    expect(raw['ratingPresentationConfig'], isA<Map>());
  });

  test('concurrent saves preserve both independent settings', () async {
    const config = RatingPresentationConfig(
      colorRules: [
        ScoreColorRule(
          id: 'concurrent-color',
          minScore: 0,
          maxScore: 10,
          colorHex: '#135790',
          enabled: true,
          order: 0,
        ),
      ],
    );

    await Future.wait([
      service.saveTmdbToken('concurrent-token'),
      service.saveRatingPresentationConfig(config),
    ]);

    expect(await service.readTmdbToken(), 'concurrent-token');
    expect(
      (await service.readRatingPresentationConfig()).colorRules.single.id,
      'concurrent-color',
    );
  });

  test('malformed presentation data is read without failing settings',
      () async {
    settingsFile.parent.createSync(recursive: true);
    await settingsFile.writeAsString(
      jsonEncode({
        'tmdbToken': 'token',
        'ratingPresentationConfig': {
          'colorRules': [
            {
              'id': 'valid',
              'minScore': 0,
              'maxScore': 10,
              'colorHex': '#010203',
              'enabled': true,
              'order': 0,
            },
            {
              'id': 'invalid',
              'minScore': -1,
              'maxScore': 10,
              'colorHex': '#010203',
              'enabled': true,
              'order': 1,
            },
          ],
          'tags': 'not-a-list',
          'style': {'inactiveStarColorHex': 'not-a-color'},
        },
      }),
    );

    final restored = await service.readRatingPresentationConfig();

    expect(restored.colorRules.single.id, 'valid');
    expect(restored.tags, isEmpty);
    expect(restored.style.inactiveStarColorHex, isNull);
    expect(await service.readTmdbToken(), 'token');
  });

  test('invalid settings JSON falls back to initialized defaults', () async {
    settingsFile.parent.createSync(recursive: true);
    await settingsFile.writeAsString('{broken');

    expect(
      (await service.readRatingPresentationConfig()).colorRules,
      hasLength(5),
    );
    expect(await service.readTmdbToken(), isNull);
  });
}
