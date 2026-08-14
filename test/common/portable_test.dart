import 'dart:io';

import 'package:fl_clash/common/portable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory root;
  late PortableStorage storage;
  late Directory supportDirectory;
  late Directory cacheDirectory;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('flclash_portable_test_');
    supportDirectory = Directory(path.join(root.path, 'support'));
    cacheDirectory = Directory(path.join(root.path, 'cache'));
    storage = PortableStorage(
      executableDirPath: path.join(root.path, 'app'),
      applicationSupportPath: supportDirectory.path,
      applicationCachePath: cacheDirectory.path,
    );
    await Directory(storage.executableDirPath).create(recursive: true);
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
    'moves application data and cache into the executable directory',
    () async {
      await File(path.join(supportDirectory.path, 'config.yaml'))
          .create(recursive: true)
          .then((file) => file.writeAsString('mixed-port: 7890'));
      await File(path.join(supportDirectory.path, 'profiles', '1.yaml'))
          .create(recursive: true)
          .then((file) => file.writeAsString('proxies: []'));
      await File(
        path.join(cacheDirectory.path, 'icons', 'logo.png'),
      ).create(recursive: true).then((file) => file.writeAsString('icon'));

      await storage.enable();

      expect(await storage.isEnabled, isTrue);
      expect(
        storage.modeFilePath,
        path.join(storage.dataPath, portableModeFileName),
      );
      expect(
        await File(path.join(storage.dataPath, 'config.yaml')).readAsString(),
        'mixed-port: 7890',
      );
      expect(
        await File(
          path.join(storage.dataPath, 'profiles', '1.yaml'),
        ).readAsString(),
        'proxies: []',
      );
      expect(
        await File(
          path.join(storage.cachePath, 'icons', 'logo.png'),
        ).readAsString(),
        'icon',
      );
      expect(await supportDirectory.exists(), isFalse);
      expect(await cacheDirectory.exists(), isFalse);
    },
  );

  test(
    'disables portable mode without moving or deleting portable data',
    () async {
      await Directory(storage.dataPath).create(recursive: true);
      await File(
        path.join(storage.dataPath, 'database.sqlite'),
      ).writeAsString('database');
      await File(
        path.join(storage.cachePath, 'icons', 'logo.png'),
      ).create(recursive: true).then((file) => file.writeAsString('icon'));
      await File(storage.modeFilePath).writeAsString('1');

      await storage.disable();

      expect(await storage.isEnabled, isFalse);
      expect(
        await File(
          path.join(storage.dataPath, 'database.sqlite'),
        ).readAsString(),
        'database',
      );
      expect(
        await File(
          path.join(storage.cachePath, 'icons', 'logo.png'),
        ).readAsString(),
        'icon',
      );
      expect(await supportDirectory.exists(), isFalse);
      expect(await cacheDirectory.exists(), isFalse);
      expect(await Directory(storage.dataPath).exists(), isTrue);
    },
  );

  test('does not overwrite an existing portable data directory', () async {
    await File(
      path.join(storage.dataPath, 'existing.txt'),
    ).create(recursive: true).then((file) => file.writeAsString('existing'));

    expect(storage.enable, throwsStateError);
  });

  test('copies nested files while creating target directories', () async {
    await File(
      path.join(supportDirectory.path, 'profiles', '1.yaml'),
    ).create(recursive: true).then((file) => file.writeAsString('proxies: []'));

    await storage.enable();

    expect(
      await File(
        path.join(storage.dataPath, 'profiles', '1.yaml'),
      ).readAsString(),
      'proxies: []',
    );
  });
}
