import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../db/app_database.dart';
import '../db/database_provider.dart';
import '../models/backup_data.dart';
import '../models/backup_manifest.dart';
import '../repositories/work_repository.dart';
import 'cover_service.dart';

// --- Public Types ---

enum ImportMode { overwrite, merge }

class ImportResult {
  const ImportResult({
    required this.inserted,
    required this.skipped,
    required this.coverFilesExtracted,
  });

  final int inserted;
  final int skipped;
  final int coverFilesExtracted;
}

class ParsedBackup {
  const ParsedBackup({
    required this.manifest,
    required this.entries,
    required this.coverFiles,
  });

  final BackupManifest manifest;
  final List<Map<String, Object?>> entries;
  final List<CoverFileEntry> coverFiles;
}

class CoverFileEntry {
  const CoverFileEntry({required this.zipPath, required this.bytes});

  final String zipPath;
  final List<int> bytes;
}

// --- Riverpod Provider ---

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    db: ref.watch(appDatabaseProvider),
    workRepository: ref.watch(workRepositoryProvider),
    coverService: ref.watch(coverServiceProvider),
  );
});

// --- BackupService ---

class BackupService {
  BackupService({
    required AppDatabase db,
    required WorkRepository workRepository,
    required CoverService coverService,
    String? coversDirOverride,
    String? backupDirOverride,
    DateTime Function()? now,
  })  : _db = db,
        _workRepository = workRepository,
        _coverService = coverService,
        _coversDirOverride = coversDirOverride,
        _backupDirOverride = backupDirOverride,
        _now = now ?? DateTime.now;

  final AppDatabase _db;
  final WorkRepository _workRepository;
  final CoverService _coverService;
  final String? _coversDirOverride;
  final String? _backupDirOverride;
  final DateTime Function() _now;
  final _uuid = const Uuid();

  // --- Export ---

  Future<String> exportToZip({String? savePath}) async {
    final createdAt = _now();
    final zipBytes = await _buildZipArchive(createdAt);
    if (zipBytes.isEmpty) {
      throw Exception('无法生成备份包：压缩数据为空。');
    }

    final dateStr = _dateStamp(createdAt);
    final fileName = 'HanaBook-backup-$dateStr.zip';

    if (savePath != null) {
      final outputFile = File(savePath);
      final parent = outputFile.parent;
      if (!parent.existsSync()) {
        parent.createSync(recursive: true);
      }
      await outputFile.writeAsBytes(zipBytes);
      return savePath;
    }

    // Try Downloads folder first (user-accessible), fall back to app storage.
    String backupDirPath;
    if (_backupDirOverride case final override?) {
      backupDirPath = override;
    } else {
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          backupDirPath = p.join(downloadsDir.path, AppConstants.displayName);
        } else {
          throw Exception('downloads unavailable');
        }
      } catch (_) {
        try {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            backupDirPath = p.join(extDir.path, AppConstants.displayName);
          } else {
            throw Exception('external storage unavailable');
          }
        } catch (_) {
          final documentsDir = await getApplicationDocumentsDirectory();
          backupDirPath = p.join(
            documentsDir.path,
            AppConstants.dataRootName,
            'backups',
          );
        }
      }
    }

    final backupDir = Directory(backupDirPath);
    if (!backupDir.existsSync()) {
      backupDir.createSync(recursive: true);
    }

    final outputFile = File(p.join(backupDir.path, fileName));
    await outputFile.writeAsBytes(zipBytes);

    return outputFile.path;
  }

  Future<List<int>> _buildZipArchive(DateTime createdAt) async {
    final entries = await _workRepository.fetchAllForExport();

    final data = BackupData(entries: entries);
    const encoder = JsonEncoder.withIndent('  ');
    final dataJson = utf8.encode(encoder.convert(data.toJson()));

    final manifest = BackupManifest.hanaBook(
      createdAt: createdAt,
      platform: Platform.operatingSystem,
    );
    final manifestJson = utf8.encode(encoder.convert(manifest.toJson()));

    final archive = Archive();
    archive.addFile(
      ArchiveFile('manifest.json', manifestJson.length, manifestJson),
    );
    archive.addFile(
      ArchiveFile('data/entries.json', dataJson.length, dataJson),
    );

    final archivedCoverSources = <String, String>{};
    for (final entry in entries) {
      final coverPath = entry['coverPath'] as String?;
      if (coverPath == null || coverPath.trim().isEmpty) continue;

      final coverFile = await _coverService.resolveCoverFile(coverPath);
      if (coverFile == null) continue;

      final fileName = p.basename(coverFile.path);
      final sourcePath = p.normalize(coverFile.absolute.path);
      final previousSource = archivedCoverSources[fileName];
      if (previousSource != null) {
        if (previousSource == sourcePath) continue;
        throw Exception('无法生成备份包：存在同名但来源不同的封面文件 $fileName。');
      }
      archivedCoverSources[fileName] = sourcePath;

      final bytes = await coverFile.readAsBytes();
      archive.addFile(
        ArchiveFile('assets/covers/$fileName', bytes.length, bytes),
      );
    }

    final zipBytes = ZipEncoder().encode(archive);
    return zipBytes ?? <int>[];
  }

  // --- Parse ---

  Future<ParsedBackup> parseZipFile(String zipPath) async {
    final file = File(zipPath);
    if (!file.existsSync()) {
      throw Exception('备份文件不存在：$zipPath');
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    } catch (_) {
      throw Exception('备份包格式错误：ZIP 文件损坏或无法读取。');
    }

    final manifestFile = _requiredArchiveFile(archive, 'manifest.json');
    final manifestMap = _readJsonObject(manifestFile, 'manifest.json');

    // The current format is selected only by its neutral format identifier.
    // appName is informational and never participates in format detection.
    if (manifestMap.containsKey('formatIdentifier')) {
      return _parseCurrentBackup(archive, manifestMap);
    }

    // Recallio v1 had no format identifier. Detect it by its version fields
    // and flat archive structure, not by the historical app brand string.
    if (_looksLikeLegacyBackup(manifestMap)) {
      return _parseLegacyBackup(archive, manifestMap);
    }

    throw Exception('备份包格式错误：无法识别备份格式。');
  }

  ParsedBackup _parseCurrentBackup(
    Archive archive,
    Map<String, Object?> manifestMap,
  ) {
    final manifest = _readCurrentManifest(manifestMap);
    if (manifest.formatIdentifier != AppConstants.backupFormatIdentifier) {
      throw Exception(
        '不支持的备份格式标识：${manifest.formatIdentifier}。',
      );
    }
    if (manifest.formatVersion != AppConstants.backupFormatVersion) {
      throw Exception(
        '备份包格式版本（${manifest.formatVersion}）不受当前版本支持'
        '（支持 ${AppConstants.backupFormatVersion}），请升级应用后重试。',
      );
    }

    final data = _readBackupData(archive, 'data/entries.json');
    return ParsedBackup(
      manifest: manifest,
      entries: data.entries,
      coverFiles: _readCoverFiles(archive, 'assets/covers/'),
    );
  }

  ParsedBackup _parseLegacyBackup(
    Archive archive,
    Map<String, Object?> manifestMap,
  ) {
    final manifest = _readLegacyManifest(manifestMap);
    if (manifest.formatVersion > AppConstants.legacyBackupSchemaVersion) {
      throw Exception(
        '旧版备份格式版本（${manifest.formatVersion}）高于当前支持的版本'
        '（${AppConstants.legacyBackupSchemaVersion}），请升级应用后重试。',
      );
    }

    final data = _readBackupData(archive, 'data.json');
    return ParsedBackup(
      manifest: manifest,
      entries: data.entries,
      coverFiles: _readCoverFiles(archive, 'covers/'),
    );
  }

  bool _looksLikeLegacyBackup(Map<String, Object?> manifestMap) {
    return manifestMap.containsKey('schemaVersion') &&
        manifestMap.containsKey('exportedAt');
  }

  BackupManifest _readCurrentManifest(Map<String, Object?> manifestMap) {
    try {
      return BackupManifest.fromCurrentJson(manifestMap);
    } on FormatException catch (error) {
      throw Exception('备份包格式错误：${error.message}');
    }
  }

  BackupManifest _readLegacyManifest(Map<String, Object?> manifestMap) {
    try {
      return BackupManifest.fromLegacyJson(manifestMap);
    } on FormatException catch (error) {
      throw Exception('备份包格式错误：${error.message}');
    }
  }

  BackupData _readBackupData(Archive archive, String path) {
    final file = _requiredArchiveFile(archive, path);
    return BackupData.fromJson(_readJsonObject(file, path));
  }

  ArchiveFile _requiredArchiveFile(Archive archive, String path) {
    final matches = archive.files
        .where((file) => file.isFile && file.name == path)
        .toList();
    if (matches.isEmpty) {
      throw Exception('备份包格式错误：缺少 $path。');
    }
    if (matches.length > 1) {
      throw Exception('备份包格式错误：$path 出现重复条目。');
    }
    return matches.single;
  }

  Map<String, Object?> _readJsonObject(ArchiveFile file, String path) {
    final content = file.content;
    if (content is! List<int>) {
      throw Exception('备份包格式错误：$path 无法读取。');
    }

    try {
      final decoded = jsonDecode(utf8.decode(content));
      if (decoded is! Map) {
        throw const FormatException();
      }
      return decoded.cast<String, Object?>();
    } catch (_) {
      throw Exception('备份包格式错误：$path 不是有效的 JSON 对象。');
    }
  }

  List<CoverFileEntry> _readCoverFiles(Archive archive, String prefix) {
    final result = <CoverFileEntry>[];
    final seenNames = <String>{};
    for (final file in archive.files) {
      if (!file.isFile || !file.name.startsWith(prefix)) continue;

      final relativeName = file.name.substring(prefix.length);
      if (relativeName.isEmpty ||
          relativeName.contains('/') ||
          relativeName.contains(r'\') ||
          relativeName == '.' ||
          relativeName == '..') {
        throw Exception('备份包格式错误：资源路径不安全（${file.name}）。');
      }
      if (!seenNames.add(relativeName)) {
        throw Exception('备份包格式错误：资源文件名重复（$relativeName）。');
      }

      final content = file.content;
      if (content is! List<int>) {
        throw Exception('备份包格式错误：资源文件无法读取（${file.name}）。');
      }
      result.add(CoverFileEntry(zipPath: file.name, bytes: content));
    }
    return result;
  }

  // --- Import ---

  Future<ImportResult> importFromParsed(
    ParsedBackup parsed, {
    required ImportMode mode,
  }) async {
    int inserted = 0;
    int skipped = 0;
    int coversExtracted = 0;
    final restoredCoverNames = parsed.coverFiles
        .map((entry) => _portableBasename(entry.zipPath))
        .toSet();

    await _db.transaction(() async {
      for (final entry in parsed.entries) {
        final workId = entry['id'] as String? ?? '';
        final importedCoverPath = _normalizeImportedCoverPath(
          entry['coverPath'] as String?,
          restoredCoverNames,
        );

        final existing = await (_db.select(_db.works)
              ..where((tbl) => tbl.id.equals(workId)))
            .getSingleOrNull();

        if (existing != null && mode == ImportMode.merge) {
          skipped++;
          continue;
        }

        if (existing != null) {
          await (_db.delete(_db.recordEntries)
                ..where((tbl) => tbl.workId.equals(workId)))
              .go();
          await (_db.delete(_db.works)..where((tbl) => tbl.id.equals(workId)))
              .go();
        }

        await _db.into(_db.works).insert(
              WorksCompanion.insert(
                id: workId,
                type: entry['type'] as String? ?? 'anime',
                title: entry['title'] as String? ?? '',
                coverPath: Value(importedCoverPath),
                sourceProvider: Value(entry['sourceProvider'] as String?),
                sourceId: Value(entry['sourceId'] as String?),
                sourceUrl: Value(entry['sourceUrl'] as String?),
                createdAt: entry['createdAt'] as String? ??
                    DateTime.now().toIso8601String(),
                updatedAt: entry['updatedAt'] as String? ??
                    DateTime.now().toIso8601String(),
                deletedAt: Value(entry['deletedAt'] as String?),
              ),
              mode: InsertMode.insertOrReplace,
            );

        final hasRecord = entry['rating'] != null ||
            (entry['review'] as String?)?.isNotEmpty == true ||
            (entry['recordDate'] as String?)?.isNotEmpty == true;

        final recordId = _uuid.v4();
        final now = DateTime.now().toIso8601String();

        await _db.into(_db.recordEntries).insert(
              RecordEntriesCompanion.insert(
                id: recordId,
                workId: workId,
                status: hasRecord ? 'finished' : 'planned',
                rating: Value((entry['rating'] as num?)?.toDouble()),
                review: Value(entry['review'] as String?),
                startDate: Value(entry['recordDate'] as String?),
                createdAt: now,
                updatedAt: now,
                deletedAt: Value(entry['deletedAt'] as String?),
              ),
              mode: InsertMode.insertOrReplace,
            );

        inserted++;
      }

      final coversDir = await _coversDir();
      for (final coverEntry in parsed.coverFiles) {
        if (coverEntry.bytes.isEmpty) continue;

        final fileName = p.basename(coverEntry.zipPath);
        final targetPath = p.join(coversDir.path, fileName);
        await File(targetPath).writeAsBytes(coverEntry.bytes);
        coversExtracted++;
      }
    });

    return ImportResult(
      inserted: inserted,
      skipped: skipped,
      coverFilesExtracted: coversExtracted,
    );
  }

  String? _normalizeImportedCoverPath(
    String? rawPath,
    Set<String> restoredCoverNames,
  ) {
    if (rawPath == null || rawPath.trim().isEmpty) return rawPath;

    final fileName = _portableBasename(rawPath.trim());
    if (!restoredCoverNames.contains(fileName)) return rawPath;

    // Historical Windows backups stored relative paths with backslashes.
    // Rebuild the path for the destination platform once its asset is restored.
    return p.join('covers', fileName);
  }

  String _portableBasename(String value) {
    return p.posix.basename(value.replaceAll(r'\', '/'));
  }

  Future<Directory> _coversDir() async {
    if (_coversDirOverride != null) {
      final dir = Directory(_coversDirOverride);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir;
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory(
      p.join(documentsDir.path, AppConstants.dataRootName, 'covers'),
    );
    if (!coversDir.existsSync()) {
      coversDir.createSync(recursive: true);
    }
    return coversDir;
  }

  String _dateStamp(DateTime value) {
    return '${value.year}-${_pad(value.month)}-${_pad(value.day)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
