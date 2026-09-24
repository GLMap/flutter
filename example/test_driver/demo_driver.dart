import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final root = Directory(
      Platform.environment['DEMO_SCREENSHOT_DIR'] ??
          'build/demo-screenshots',
    );
    await root.create(recursive: true);
    await File('${root.path}/$name.png').writeAsBytes(bytes);
    return true;
  },
);
