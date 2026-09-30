#!/usr/bin/env python3
from pathlib import Path
import re,json
root=Path(__file__).resolve().parents[1]
pin=json.loads((root/'native-sdk.json').read_text())
version=pin['releaseVersion']
for name in ('glmap_core','glmap','glsearch','glroute'):
 p=root/'packages'/name;text=(p/'pubspec.yaml').read_text()
 assert f'name: {name}\n' in text
 # pub.dev rejects an explicit publish_to URL; omit it to use the default registry.
 assert not re.search(r'^publish_to\s*:',text,re.M), f'{name}: omit publish_to for pub.dev'
 assert f'repository: https://github.com/GLMap/flutter/tree/main/packages/{name}\n' in text
 assert not any(re.search('^  '+other+':',text,re.M) for other in ('glmap','glsearch','glroute') if other!=name)
 if name!='glmap_core':assert '  glmap_core: ^0.1.0-beta.1' in text
 android=(p/'android/build.gradle.kts').read_text()
 if name!='glmap':assert 'globus:glmap:' not in android
 assert f'?: "{version}"' in android, f'{name}: Android SDK pin differs from native-sdk.json'
 apple=(p/f'ios/{name}/Package.swift').read_text()
 assert f'.package(url: "{pin["swiftPackage"]}", exact: "{version}")' in apple, f'{name}: SwiftPM SDK pin differs from native-sdk.json'
 assert pin['androidRepository'] in android
 print('PASS',name,'native SDK',version)
for host in ('Runner.xcodeproj/project.xcworkspace', 'Runner.xcworkspace'):
 lock=root/f'example/ios/{host}/xcshareddata/swiftpm/Package.resolved'
 pins=json.loads(lock.read_text())['pins']
 sdk=next(p for p in pins if p['identity']=='glmapswift')
 assert sdk['location']==pin['swiftPackage']
 assert sdk['state']=={'version':version,'revision':pin['swiftPackageRevision']}, f'{host}: stale demo SwiftPM lock'
print('PASS demo SwiftPM locks',version)
