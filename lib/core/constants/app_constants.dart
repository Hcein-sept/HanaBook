class AppConstants {
  const AppConstants._();

  static const displayName = 'HanaBook';

  // Keep synchronized with pubspec.yaml. This avoids adding a runtime package
  // dependency solely for backup metadata.
  static const appVersion = '0.1.0+1';

  static const backupFormatIdentifier = 'personal-media-library-backup';
  static const backupFormatVersion = 2;

  static const legacyBackupSchemaVersion = 1;

  // Kept for compatibility with existing local application data.
  static const dataRootName = 'Recallio App Data';
  static const databaseFileName = 'recallio.sqlite';
}
