import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:recallio/core/constants/app_constants.dart';
import 'package:recallio/db/app_database.dart';
import 'package:recallio/models/backup_manifest.dart';
import 'package:recallio/models/record_status.dart';
import 'package:recallio/models/work_type.dart';
import 'package:recallio/repositories/work_repository.dart';
import 'package:recallio/services/backup_service.dart';
import 'package:recallio/services/cover_service.dart';

void main() {
  late AppDatabase database;
  late WorkRepository repository;
  late BackupService service;
  late Directory tempDirectory;
  late String coversTempDir;

  setUp(() {
    tempDirectory =
        Directory.systemTemp.createTempSync('hanabook_backup_test_');
    coversTempDir = '${tempDirectory.path}/covers';
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = WorkRepository(database, CoverService());
    service = BackupService(
      db: database,
      workRepository: repository,
      coverService: CoverService(),
      coversDirOverride: coversTempDir,
      backupDirOverride: '${tempDirectory.path}/exports',
      now: () => DateTime(2026, 9, 18, 12, 30),
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDirectory.existsSync()) {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  // --- Task 1: fetchAllForExport ---

  test('fetchAllForExport returns all non-deleted works with record data',
      () async {
    await repository.saveWork(
      const WorkFormData(
        workId: null,
        type: WorkType.anime,
        title: 'Test Anime',
        originalTitle: '',
        aliasesText: '',
        summary: '',
        coverPath: 'covers/test.jpg',
        coverSourcePath: null,
        releaseDate: '',
        creatorsText: '',
        status: RecordStatus.finished,
        rating: 8.5,
        shortComment: '',
        review: 'Great show',
        spoilerReview: '',
        startDate: '2026-01-01',
        finishDate: '',
        progress: '',
        platform: '',
        tagNames: [],
        sourceProvider: 'manual',
        sourceId: null,
        sourceUrl: null,
      ),
    );

    final entries = await repository.fetchAllForExport();

    expect(entries, hasLength(1));
    expect(entries.single['title'], 'Test Anime');
    expect(entries.single['type'], 'anime');
    expect(entries.single['coverPath'], 'covers/test.jpg');
    expect(entries.single['rating'], 8.5);
    expect(entries.single['review'], 'Great show');
    expect(entries.single['recordDate'], '2026-01-01');
    expect(entries.single['sourceProvider'], 'manual');
  });

  test('fetchAllForExport handles null recordDate gracefully', () async {
    await repository.saveWork(
      WorkFormData(
        workId: null,
        type: WorkType.game,
        title: 'No Date Game',
        originalTitle: '',
        aliasesText: '',
        summary: '',
        coverPath: null,
        coverSourcePath: null,
        releaseDate: '',
        creatorsText: '',
        status: RecordStatus.planned,
        rating: null,
        shortComment: '',
        review: '',
        spoilerReview: '',
        startDate: '',
        finishDate: '',
        progress: '',
        platform: '',
        tagNames: [],
      ),
    );

    final entries = await repository.fetchAllForExport();

    expect(entries, hasLength(1));
    expect(entries.single['rating'], isNull);
    expect(entries.single['review'], isNull);
    // recordDate falls back to createdAt date portion (10 chars)
    expect(entries.single['recordDate'], isNotNull);
    expect(entries.single['recordDate']!.toString().length, 10);
  });

  test('fetchAllForExport excludes soft-deleted works', () async {
    final workId = await repository.saveWork(
      WorkFormData(
        workId: null,
        type: WorkType.manga,
        title: 'To Delete',
        originalTitle: '',
        aliasesText: '',
        summary: '',
        coverPath: null,
        coverSourcePath: null,
        releaseDate: '',
        creatorsText: '',
        status: RecordStatus.planned,
        rating: null,
        shortComment: '',
        review: '',
        spoilerReview: '',
        startDate: '',
        finishDate: '',
        progress: '',
        platform: '',
        tagNames: [],
      ),
    );

    await repository.softDeleteWork(workId);

    final entries = await repository.fetchAllForExport();
    expect(entries, isEmpty);
  });

  // --- Zip Parsing ---

  Map<String, Object?> sampleEntry({
    String id = 'entry-1',
    String title = 'Test Entry',
    String type = 'anime',
    double? rating = 8.5,
    String? review = 'Test review',
    String? coverPath,
  }) {
    return {
      'id': id,
      'title': title,
      'type': type,
      'coverPath': coverPath,
      'rating': rating,
      'review': review,
      'recordDate': '2026-07-21',
      'sourceProvider': 'manual',
      'sourceId': null,
      'sourceUrl': null,
      'createdAt': '2026-07-21T10:00:00.000',
      'updatedAt': '2026-07-21T10:00:00.000',
      'deletedAt': null,
    };
  }

  Future<String> writeArchive(Archive archive, String fileName) async {
    final zipBytes = ZipEncoder().encode(archive)!;
    final zipPath = '${tempDirectory.path}/$fileName';
    await File(zipPath).writeAsBytes(zipBytes);
    return zipPath;
  }

  Future<String> createLegacyRecallioZip({
    String app = 'Recallio',
    int schemaVersion = 1,
    List<Map<String, Object?>> entries = const [],
    Map<String, List<int>> covers = const {},
    bool includeManifest = true,
    bool includeData = true,
    String fileName = 'recallio_backup_2026-07-21.zip',
  }) async {
    final archive = Archive();
    const encoder = JsonEncoder.withIndent('  ');

    if (includeManifest) {
      final manifest = {
        'app': app,
        'schemaVersion': schemaVersion,
        'exportedAt': '2026-07-21T10:00:00.000',
        'sourceClient': 'flutter-local',
        'platform': 'windows',
      };
      final manifestJson = utf8.encode(encoder.convert(manifest));
      archive.addFile(
        ArchiveFile('manifest.json', manifestJson.length, manifestJson),
      );
    }

    if (includeData) {
      final data = {'entries': entries};
      final dataJson = utf8.encode(encoder.convert(data));
      archive.addFile(
        ArchiveFile('data.json', dataJson.length, dataJson),
      );
    }

    for (final cover in covers.entries) {
      archive.addFile(
        ArchiveFile(
          'covers/${cover.key}',
          cover.value.length,
          cover.value,
        ),
      );
    }

    return writeArchive(archive, fileName);
  }

  Future<String> createHanaBookZip({
    String formatIdentifier = 'personal-media-library-backup',
    int formatVersion = 2,
    String appName = 'HanaBook',
    List<Map<String, Object?>> entries = const [],
    Map<String, List<int>> covers = const {},
    bool includeManifest = true,
    bool includeData = true,
    String fileName = 'HanaBook-backup-2026-07-21.zip',
  }) async {
    final archive = Archive();
    const encoder = JsonEncoder.withIndent('  ');

    if (includeManifest) {
      final manifest = {
        'formatIdentifier': formatIdentifier,
        'formatVersion': formatVersion,
        'appName': appName,
        'appVersion': '0.1.0+1',
        'createdAt': '2026-07-21T10:00:00.000',
        'sourceClient': 'flutter-local',
        'platform': 'windows',
      };
      final manifestJson = utf8.encode(encoder.convert(manifest));
      archive.addFile(
        ArchiveFile('manifest.json', manifestJson.length, manifestJson),
      );
    }

    if (includeData) {
      final dataJson = utf8.encode(encoder.convert({'entries': entries}));
      archive.addFile(
        ArchiveFile('data/entries.json', dataJson.length, dataJson),
      );
    }

    for (final cover in covers.entries) {
      archive.addFile(
        ArchiveFile(
          'assets/covers/${cover.key}',
          cover.value.length,
          cover.value,
        ),
      );
    }

    return writeArchive(archive, fileName);
  }

  test('legacy Recallio ZIP imports successfully into HanaBook', () async {
    final zipPath = await createLegacyRecallioZip(
      entries: [sampleEntry(coverPath: r'covers\legacy.jpg')],
      covers: const {
        'legacy.jpg': [4, 5, 6]
      },
    );

    final parsed = await service.parseZipFile(zipPath);
    expect(parsed.manifest.isLegacy, isTrue);
    expect(parsed.manifest.appName, 'Recallio');
    expect(parsed.manifest.formatVersion, 1);
    expect(parsed.entries.single['title'], 'Test Entry');

    final result = await service.importFromParsed(
      parsed,
      mode: ImportMode.overwrite,
    );
    expect(result.inserted, 1);
    expect(result.coverFilesExtracted, 1);
    final restored = await repository.fetchDetail('entry-1');
    expect(restored?.work.title, 'Test Entry');
    expect(restored?.work.coverPath, p.join('covers', 'legacy.jpg'));
    expect(restored?.rating, 8.5);
    expect(restored?.review, 'Test review');
    expect(await File('$coversTempDir/legacy.jpg').readAsBytes(), [4, 5, 6]);
  });

  test('new HanaBook ZIP imports successfully', () async {
    final zipPath = await createHanaBookZip(
      entries: [sampleEntry(id: 'new-entry', title: 'New Format Entry')],
      covers: const {
        'cover.jpg': [1, 2, 3]
      },
    );

    final parsed = await service.parseZipFile(zipPath);
    expect(parsed.manifest.isLegacy, isFalse);
    expect(
        parsed.manifest.formatIdentifier, AppConstants.backupFormatIdentifier);
    expect(parsed.manifest.formatVersion, AppConstants.backupFormatVersion);
    expect(parsed.manifest.appName, 'HanaBook');
    expect(parsed.coverFiles.single.zipPath, 'assets/covers/cover.jpg');

    final result = await service.importFromParsed(
      parsed,
      mode: ImportMode.overwrite,
    );
    expect(result.inserted, 1);
    expect(result.coverFilesExtracted, 1);
    expect((await repository.fetchDetail('new-entry'))?.work.title,
        'New Format Entry');
    expect(await File('$coversTempDir/cover.jpg').readAsBytes(), [1, 2, 3]);
  });

  test('brand metadata never decides new or legacy parser', () async {
    final currentPath = await createHanaBookZip(
      appName: 'User Renamed App',
      entries: [sampleEntry()],
      fileName: 'current-other-app.zip',
    );
    final legacyPath = await createLegacyRecallioZip(
      app: 'User Renamed App',
      entries: [sampleEntry()],
      fileName: 'legacy-other-app.zip',
    );

    expect(
        (await service.parseZipFile(currentPath)).manifest.isLegacy, isFalse);
    expect((await service.parseZipFile(legacyPath)).manifest.isLegacy, isTrue);
  });

  test('renamed ZIP still imports because filename is ignored', () async {
    final originalPath = await createHanaBookZip(
      entries: [sampleEntry(id: 'renamed-entry')],
    );
    final renamedPath = '${tempDirectory.path}/用户重命名的收藏.zip';
    await File(originalPath).rename(renamedPath);

    final parsed = await service.parseZipFile(renamedPath);
    final result = await service.importFromParsed(
      parsed,
      mode: ImportMode.overwrite,
    );

    expect(result.inserted, 1);
    expect(await repository.fetchDetail('renamed-entry'), isNotNull);
  });

  test('parseZipFile rejects an unknown current format identifier', () async {
    final zipPath = await createHanaBookZip(
      formatIdentifier: 'unknown-backup-format',
    );

    await expectLater(
      service.parseZipFile(zipPath),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('不支持的备份格式标识'),
        ),
      ),
    );
  });

  test('parseZipFile rejects unsupported current format version', () async {
    final zipPath = await createHanaBookZip(formatVersion: 99);

    await expectLater(
      service.parseZipFile(zipPath),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('格式版本'),
        ),
      ),
    );
  });

  test('parseZipFile throws when manifest is missing', () async {
    final zipPath = await createHanaBookZip(includeManifest: false);

    await expectLater(
      service.parseZipFile(zipPath),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('缺少 manifest.json'),
        ),
      ),
    );
  });

  test('parseZipFile throws when data.json is missing', () async {
    final zipPath = await createLegacyRecallioZip(includeData: false);

    await expectLater(
      service.parseZipFile(zipPath),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('缺少 data.json'),
        ),
      ),
    );
  });

  test('parseZipFile throws when current data file is missing', () async {
    final zipPath = await createHanaBookZip(includeData: false);

    await expectLater(
      service.parseZipFile(zipPath),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('缺少 data/entries.json'),
        ),
      ),
    );
  });

  test('export uses HanaBook filename and neutral v2 archive structure',
      () async {
    final sourceCover = File('${tempDirectory.path}/cover.jpg');
    await sourceCover.writeAsBytes([7, 8, 9]);
    await repository.saveWork(
      WorkFormData(
        workId: 'wire-format-work',
        type: WorkType.anime,
        title: 'Wire Format Work',
        originalTitle: '',
        aliasesText: '',
        summary: '',
        coverPath: sourceCover.path,
        coverSourcePath: null,
        releaseDate: '',
        creatorsText: '',
        status: RecordStatus.planned,
        rating: null,
        shortComment: '',
        review: '',
        spoilerReview: '',
        startDate: '',
        finishDate: '',
        progress: '',
        platform: '',
        tagNames: [],
      ),
    );
    await repository.saveWork(
      WorkFormData(
        workId: 'shared-cover-work',
        type: WorkType.movie,
        title: 'Shared Cover Work',
        originalTitle: '',
        aliasesText: '',
        summary: '',
        coverPath: sourceCover.path,
        coverSourcePath: null,
        releaseDate: '',
        creatorsText: '',
        status: RecordStatus.planned,
        rating: null,
        shortComment: '',
        review: '',
        spoilerReview: '',
        startDate: '',
        finishDate: '',
        progress: '',
        platform: '',
        tagNames: [],
      ),
    );
    final outputPath = await service.exportToZip();

    expect(p.basename(outputPath), 'HanaBook-backup-2026-09-18.zip');
    final archive =
        ZipDecoder().decodeBytes(await File(outputPath).readAsBytes());
    final fileNames = archive.files
        .where((file) => file.isFile)
        .map((file) => file.name)
        .toList();
    expect(
      fileNames,
      containsAll([
        'manifest.json',
        'data/entries.json',
        'assets/covers/cover.jpg',
      ]),
    );
    expect(fileNames, isNot(contains('data.json')));
    expect(fileNames.where((name) => name.startsWith('Recallio/')), isEmpty);
    expect(fileNames.where((name) => name.startsWith('HanaBook/')), isEmpty);
    expect(
      fileNames.where((name) => name == 'assets/covers/cover.jpg'),
      hasLength(1),
    );

    final manifestFile = archive.findFile('manifest.json')!;
    final manifest = jsonDecode(
      utf8.decode(manifestFile.content as List<int>),
    ) as Map<String, dynamic>;
    expect(
      manifest['formatIdentifier'],
      AppConstants.backupFormatIdentifier,
    );
    expect(manifest['formatVersion'], AppConstants.backupFormatVersion);
    expect(manifest['appName'], 'HanaBook');
    expect(manifest['appVersion'], AppConstants.appVersion);
    expect(manifest['createdAt'], '2026-09-18T12:30:00.000');
    expect(manifest, isNot(contains('app')));
    expect(manifest, isNot(contains('schemaVersion')));
  });

  test('export then import preserves the current backup data contract',
      () async {
    await repository.saveWork(
      const WorkFormData(
        workId: 'round-trip-work',
        type: WorkType.movie,
        title: 'Round Trip Movie',
        originalTitle: '',
        aliasesText: '',
        summary: '',
        coverPath: null,
        coverSourcePath: null,
        releaseDate: '',
        creatorsText: '',
        status: RecordStatus.finished,
        rating: 9.5,
        shortComment: '',
        review: 'Round trip review',
        spoilerReview: '',
        startDate: '2026-04-05',
        finishDate: '',
        progress: '',
        platform: '',
        tagNames: [],
        sourceProvider: 'manual',
        sourceId: 'source-1',
        sourceUrl: 'https://example.invalid/item/1',
      ),
    );
    final before = await repository.fetchAllForExport();
    final zipPath = await service.exportToZip();

    await database.close();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = WorkRepository(database, CoverService());
    service = BackupService(
      db: database,
      workRepository: repository,
      coverService: CoverService(),
      coversDirOverride: '${tempDirectory.path}/target-covers',
    );
    final parsed = await service.parseZipFile(zipPath);
    final result = await service.importFromParsed(
      parsed,
      mode: ImportMode.overwrite,
    );
    final after = await repository.fetchAllForExport();

    expect(result.inserted, before.length);
    expect(after, before);
  });

  // --- Import Modes ---

  ParsedBackup syntheticBackup(List<Map<String, Object?>> entries) {
    return ParsedBackup(
      manifest: BackupManifest.hanaBook(
        createdAt: DateTime.now(),
        platform: 'test',
      ),
      entries: entries,
      coverFiles: const [],
    );
  }

  test('import merge mode skips existing work', () async {
    final workId = 'existing-work-id';

    await repository.saveWork(
      const WorkFormData(
        workId: 'existing-work-id',
        type: WorkType.anime,
        title: 'Original Title',
        originalTitle: '',
        aliasesText: '',
        summary: '',
        coverPath: null,
        coverSourcePath: null,
        releaseDate: '',
        creatorsText: '',
        status: RecordStatus.finished,
        rating: 7,
        shortComment: '',
        review: 'Original review',
        spoilerReview: '',
        startDate: '2026-01-01',
        finishDate: '',
        progress: '',
        platform: '',
        tagNames: [],
      ),
    );

    final parsed = syntheticBackup([
      {
        'id': workId,
        'title': 'New Title',
        'type': 'anime',
        'rating': 9,
        'review': 'New review',
        'recordDate': '2026-02-02',
      },
      {
        'id': 'new-work-id',
        'title': 'New Entry',
        'type': 'game',
        'rating': null,
        'review': null,
        'recordDate': null,
      },
    ]);

    final result = await service.importFromParsed(
      parsed,
      mode: ImportMode.merge,
    );

    expect(result.inserted, 1);
    expect(result.skipped, 1);

    // Existing work should be unchanged
    final existing = await repository.fetchDetail(workId);
    expect(existing!.work.title, 'Original Title');
    expect(existing.rating, 7);
    expect(existing.review, 'Original review');
  });

  test('import overwrite mode replaces existing work', () async {
    final workId = 'existing-work-id';

    await repository.saveWork(
      const WorkFormData(
        workId: 'existing-work-id',
        type: WorkType.anime,
        title: 'Original Title',
        originalTitle: '',
        aliasesText: '',
        summary: '',
        coverPath: null,
        coverSourcePath: null,
        releaseDate: '',
        creatorsText: '',
        status: RecordStatus.finished,
        rating: 7,
        shortComment: '',
        review: 'Original review',
        spoilerReview: '',
        startDate: '2026-01-01',
        finishDate: '',
        progress: '',
        platform: '',
        tagNames: [],
      ),
    );

    final parsed = syntheticBackup([
      {
        'id': workId,
        'title': 'New Title',
        'type': 'game',
        'rating': 9.5,
        'review': 'New review',
        'recordDate': '2026-02-02',
      },
    ]);

    final result = await service.importFromParsed(
      parsed,
      mode: ImportMode.overwrite,
    );

    expect(result.inserted, 1);
    expect(result.skipped, 0);

    final updated = await repository.fetchDetail(workId);
    expect(updated!.work.title, 'New Title');
    expect(updated.work.type, 'game');
    expect(updated.rating, 9.5);
    expect(updated.review, 'New review');
  });
}
