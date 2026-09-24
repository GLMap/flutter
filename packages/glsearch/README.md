# glsearch

Text/category search, autocomplete and map-object queries for Flutter on Android
and iOS. Depends on `glmap_core`, not on the Map or Route packages. Text search can
run without a map widget or renderer.

## Installation

Add [glsearch](https://pub.dev/packages/glsearch) to your Flutter app:

```sh
flutter pub add glsearch
```

## Requirements

Flutter 3.47.4+, Dart `^3.13.3`, Android API 24+ and iOS 16.4+.
The plugin depends on native GLSearch 2.2.0. Follow the
[Android/iOS host setup](../../README.md#2-configure-the-native-host) before
running your app.

## Search

Initialize `GLMapSDK` first. For offline search, register or download map data
covering the query area; the demo includes a Montenegro dataset.

```dart
import 'package:glsearch/glsearch.dart';

Future<List<GLMapPlace>> searchPodgorica() async {
  final request = GLSearch.search(
    'Podgorica',
    center: const GLMapGeoPoint(latitude: 42.4341, longitude: 19.26),
    offline: true,
  );
  return request.result;
}
```

`GLSearch.search` returns a `GLMapRequest<List<GLMapPlace>>`. Keep the request to
call `cancel()` when a query is superseded or its screen closes, and handle errors
from `result`. Optional `categories` and `autocomplete` arguments support filtered
search and suggestions. Set `offline: false` for online search with a valid key
and network access.

## Query a displayed map

When the app also uses `glmap`, import `glsearch` to enable the `pickObject`
extension on its map controller. Queries accept a Core `GLMapQueryTarget`, so the
Search package does not depend on Map. Handle completion or failure if the map is
removed while a query is pending.

See the [search examples](../../example/lib/demo/search_examples.dart) for search,
result markers, list selection and POI taps. Native SDK and map-data license terms
apply in addition to this package's [LICENSE](LICENSE).
