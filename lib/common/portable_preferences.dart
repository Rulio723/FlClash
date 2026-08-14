import 'dart:io';

import 'package:fl_clash/common/path.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

void configurePortablePreferences() {
  if (!Platform.isWindows || !appPath.isPortable) return;
  final pathProvider = _PortablePathProvider();
  PathProviderPlatform.instance = pathProvider;
  final preferences = _PortableSharedPreferencesWindows();
  SharedPreferencesStorePlatform.instance = preferences;
}

class _PortableSharedPreferencesWindows extends SharedPreferencesWindows {
  @override
  PathProviderWindows get pathProvider => _PortablePathProvider();
}

class _PortablePathProvider extends PathProviderWindows {
  @override
  Future<String?> getApplicationSupportPath() async => appPath.portableDataPath;

  @override
  Future<String?> getApplicationCachePath() async =>
      path.join(appPath.portableDataPath, 'cache');

  @override
  Future<String?> getTemporaryPath() async =>
      path.join(appPath.portableDataPath, 'temp');
}
