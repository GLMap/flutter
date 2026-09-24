#!/usr/bin/env python3
from pathlib import Path
import subprocess,shutil
repo=Path(__file__).resolve().parents[1];out=repo/'build/module-probes';out.mkdir(parents=True,exist_ok=True)
common="""import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:glmap_core/glmap_core.dart';
"""
bodies={
'core':'''await GLMapSDK.initialize(apiKey:'');
    final regions=await GLMapSDK.regions();
    expect(regions,isA<List<GLMapRegion>>());''',
'search':'''await GLMapSDK.initialize(apiKey:'');
    await GLMapSDK.addAssetDataSet('assets/Montenegro.vm',GLMapDataSet.map);
    final request=GLSearch.search('Podgorica',center:const GLMapGeoPoint(latitude:42.4341,longitude:19.26));
    final found=await request.result.timeout(const Duration(seconds:20));
    expect(found,isNotEmpty);
    await request.cancel();''',
'route':'''await GLMapSDK.initialize(apiKey:'');
    final route=await GLRouteSDK.buildRoute([const GLMapRouteStep(points:[GLMapGeoPoint(latitude:42.43,longitude:19.25),GLMapGeoPoint(latitude:42.44,longitude:19.27)],instruction:'Continue',duration:30)]);
    expect(route.distance,greaterThan(0));
    final state=await route.updateLocation(const GLMapGeoPoint(latitude:42.43,longitude:19.25));
    expect(state.remainingDistance.isFinite,isTrue);
    await route.close();await route.close();'''
}
for name in ('core','search','route'):
 app=out/name
 if not app.exists():
  subprocess.run(['flutter','create','--platforms','android,ios','--org','software.globus.modules','--project-name',f'probe_{name}','--no-pub',str(app)],check=True,stdout=subprocess.DEVNULL)
 (app/'integration_test').mkdir(exist_ok=True);(app/'assets').mkdir(exist_ok=True)
 mod={'core':'glmap_core','search':'glsearch','route':'glroute'}[name]
 deps=f'  glmap_core:\n    path: {repo}/packages/glmap_core\n'
 if mod!='glmap_core':deps+=f'  {mod}:\n    path: {repo}/packages/{mod}\n'
 (app/'pubspec.yaml').write_text(f'''name: probe_{name}
publish_to: none
environment:
  sdk: ^3.13.3
dependencies:
  flutter:
    sdk: flutter
{deps}dependency_overrides:
  glmap_core:
    path: {repo}/packages/glmap_core
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
flutter:
  uses-material-design: true
'''+('  assets:\n    - assets/Montenegro.vm\n' if name=='search' else ''))
 if name=='search':shutil.copy2(repo/'example/assets/Montenegro.vm',app/'assets/Montenegro.vm')
 (app/'integration_test/probe_test.dart').write_text(common+(f"import 'package:{mod}/{mod}.dart';\n" if name!='core' else '')+f'''void main() {{
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('{name} works without renderer', (tester) async {{
    {bodies[name]}
  }});
}}
''')
 (app/'lib/main.dart').write_text("import 'package:flutter/widgets.dart';\nvoid main()=>runApp(const SizedBox());\n")
 p=app/'android/build.gradle.kts';text=p.read_text();repoLine='maven { url = uri("https://maven.globus.software/artifactory/libs") }'
 if repoLine not in text:text=text.replace('repositories {','repositories {\n        System.getenv("GLMAP_SDK_DIR")?.let { maven { url = uri(file(it).resolve("maven")) } }\n        '+repoLine,1);p.write_text(text)
 p=app/'android/app/build.gradle.kts';text=p.read_text()
 if 'noCompress' not in text:text=text.replace('android {','android {\n    androidResources { noCompress += listOf("vm", "ttf", "otf") }',1);p.write_text(text)
 p=app/'ios/Runner.xcodeproj/project.pbxproj';text=p.read_text();import re;text=re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;', 'IPHONEOS_DEPLOYMENT_TARGET = 16.4;',text);p.write_text(text)
 subprocess.run(['flutter','pub','get'],cwd=app,check=True,stdout=subprocess.DEVNULL)
 print(app,flush=True)
