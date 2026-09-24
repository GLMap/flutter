#!/usr/bin/env python3
from pathlib import Path
import re,json
root=Path(__file__).resolve().parents[1]
for name in ('glmap_core','glmap','glsearch','glroute'):
 p=root/'packages'/name;text=(p/'pubspec.yaml').read_text()
 assert f'name: {name}\n' in text
 assert not any(re.search('^  '+other+':',text,re.M) for other in ('glmap','glsearch','glroute') if other!=name)
 if name!='glmap_core':assert '  glmap_core: ^0.1.0-beta.1' in text
 android=(p/'android/build.gradle.kts').read_text()
 if name!='glmap':assert 'globus:glmap:' not in android
 print('PASS',name)
