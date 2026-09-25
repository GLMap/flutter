#!/usr/bin/env python3
"""Check shared demo entry points, native identities and generated map wiring."""
from pathlib import Path
import plistlib
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]

def read(name):
    return (root / name).read_text()

assert "Future<void> main() => demo.main();" in read('example/lib/main.dart')
assert "import 'demo_main.dart' as demo;" in read('example/lib/main.dart')
catalog = read('example/lib/demo_main.dart')
assert len(re.findall(r'^  DemoEntry\(', catalog, re.MULTILINE)) == 20
assert "Key('open-lifecycle')" in catalog
assert 'lifecycle.LifecycleScreen(fixture: fixture)' in catalog
for sample in ('lifecycle_main.dart', 'vector_main.dart'):
    source = read('example/lib/' + sample)
    assert "import 'package:glmap/glmap.dart';" in source
    assert 'GLMapSDK.initialize(' in source
    creation = re.search(r'\bGLMap\((.*?)onCreated:', source, re.DOTALL)[1]
    assert 'initialCenter:' in creation and 'fixture:' not in creation
print('PASS shared catalog and public lifecycle/vector entries')

app_id = 'software.globus.glmap.flutter.demo'
assert 'name: glmap_example\n' in read('example/pubspec.yaml')
android = read('example/android/app/build.gradle.kts')
assert f'namespace = "{app_id}"' in android
assert f'applicationId = "{app_id}"' in android
manifest = ET.fromstring(read('example/android/app/src/main/AndroidManifest.xml'))
assert manifest.find('application').attrib['{http://schemas.android.com/apk/res/android}label'] == 'GLMap Flutter Demo'
info = plistlib.loads((root / 'example/ios/Runner/Info.plist').read_bytes())
assert info['CFBundleDisplayName'] == 'GLMap Flutter Demo'
project = read('example/ios/Runner.xcodeproj/project.pbxproj')
assert f'PRODUCT_BUNDLE_IDENTIFIER = {app_id};' in project
assert 'DEVELOPMENT_TEAM =' not in project
assert 'sourceTree = SDKROOT;' in project
for name in ('Runner', 'DemoTests'):
    ET.fromstring(read(f'example/ios/Runner.xcodeproj/xcshareddata/xcschemes/{name}.xcscheme'))
assert 'LifecycleViewTests.swift' in project
assert 'NSClassFromString("GLMapPlugin")' in read('example/ios/RunnerTests/RunnerTests.swift')
print('PASS app identities, current Swift unit tests and Xcode references')

view_files = [
    'packages/glmap/lib/glmap.dart',
    'packages/glmap/android/src/main/kotlin/software/globus/flutter/glmap/GLMapPlugin.kt',
    'packages/glmap/ios/glmap/Sources/GlobusMapFlutter/GLMapPlugin.swift',
]
for name in view_files:
    source = read(name)
    assert 'software.globus.glmap/view' in source
    assert not re.search(r'MethodChannel\([^)]*glmap', source)
assert 'Map<String, Object?> diagnostics();' in read('packages/glmap/pigeons/map.dart')
for name in (
    'packages/glmap/lib/src/map.g.dart',
    'packages/glmap/android/src/main/kotlin/software/globus/flutter/glmap/Map.g.kt',
    'packages/glmap/ios/glmap/Sources/GlobusMapFlutter/Map.g.swift',
):
    assert 'MapHostApi.diagnostics' in read(name)
for name in view_files + ['example/ios/Runner.xcodeproj/project.pbxproj', 'example/ios/RunnerTests/RunnerTests.swift']:
    assert not re.search(r'glmap_lab|GLMapLab|GlmapLab|software\.globus\.lab|StageA', read(name)), name
print('PASS coordinated platform-view identity and Pigeon diagnostics bindings')
