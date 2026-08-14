import 'dart:io';

import 'package:path/path.dart' as path;

const portableDataDirectoryName = 'FlClashData';
const portableModeFileName = '.flclash-portable';
const _cacheDirectoryName = 'cache';

class PortableStorage {
  final String executableDirPath;
  final String applicationSupportPath;
  final String applicationCachePath;

  const PortableStorage({
    required this.executableDirPath,
    required this.applicationSupportPath,
    required this.applicationCachePath,
  });

  String get dataPath =>
      path.join(executableDirPath, portableDataDirectoryName);

  String get cachePath => path.join(dataPath, _cacheDirectoryName);

  String get modeFilePath => path.join(dataPath, portableModeFileName);

  Future<bool> get isEnabled => File(modeFilePath).exists();

  Future<void> enable() async {
    if (await isEnabled) return;
    final dataDirectory = Directory(dataPath);
    if (await dataDirectory.exists() &&
        await dataDirectory.list(followLinks: false).isEmpty == false) {
      throw StateError('Portable data directory already exists.');
    }
    try {
      await _copyDirectoryContents(
        Directory(applicationSupportPath),
        dataDirectory,
      );
      await _copyDirectoryContents(
        Directory(applicationCachePath),
        Directory(cachePath),
      );
      await _deleteDirectory(Directory(applicationSupportPath));
      await _deleteDirectory(Directory(applicationCachePath));
      await File(modeFilePath).writeAsString('1', flush: true);
    } catch (_) {
      await _copyDirectoryContents(
        dataDirectory,
        Directory(applicationSupportPath),
        excludedNames: {_cacheDirectoryName},
      );
      await _copyDirectoryContents(
        Directory(cachePath),
        Directory(applicationCachePath),
      );
      await _deleteDirectory(dataDirectory);
      rethrow;
    }
  }

  Future<void> disable() async {
    if (!await isEnabled) return;
    await File(modeFilePath).delete();
  }

  Future<void> _copyDirectoryContents(
    Directory source,
    Directory destination, {
    Set<String> excludedNames = const {},
  }) async {
    if (!await source.exists()) return;
    await destination.create(recursive: true);
    await for (final entity in source.list(followLinks: false)) {
      final name = path.basename(entity.path);
      if (excludedNames.contains(name)) continue;
      final targetPath = path.join(destination.path, name);
      if (entity is File) {
        await File(targetPath).parent.create(recursive: true);
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        await _copyDirectoryContents(entity, Directory(targetPath));
      } else if (entity is Link) {
        await Link(targetPath).create(await entity.target());
      }
    }
  }

  Future<void> _deleteDirectory(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
