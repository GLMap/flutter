# glroute

Road routing, custom-route construction, maneuvers and route tracking for Flutter
on Android and iOS. Depends on `glmap_core`, not on Map or Search, and can run
without a map widget or renderer.

## Installation

Add [glroute](https://pub.dev/packages/glroute) to your Flutter app:

```sh
flutter pub add glroute
```

## Requirements

Flutter 3.47.4+, Dart `^3.13.3`, Android API 24+ and iOS 16.4+.
The plugin depends on native GLRoute 2.2.0. Follow the
[Android/iOS host setup](../../README.md#2-configure-the-native-host) before
running your app.

## Build and track a route

Initialize `GLMapSDK` before calling route APIs. A custom route uses the supplied
geometry and does not perform road routing or require a service request:

```dart
import 'package:glroute/glroute.dart';

Future<GLMapNavigationState> trackCustomRoute() async {
  const start = GLMapGeoPoint(latitude: 42.43, longitude: 19.25);
  const end = GLMapGeoPoint(latitude: 42.44, longitude: 19.27);
  final route = await GLRouteSDK.buildRoute([
    const GLMapRouteStep(
      points: [start, end],
      instruction: 'Continue',
      duration: 30,
    ),
  ]);
  try {
    return await route.updateLocation(start);
  } finally {
    await route.close();
  }
}
```

## Road routing and lifetime

- `GLRouteSDK.route` returns a cancellable `GLMapRequest<GLMapRoute>`. Select car,
  bicycle or pedestrian through `GLMapRouteMode`.
- Online road routing requires a valid API key and network access.
- Offline road routing requires downloaded navigation data and `offlineConfig`
  containing a compatible Valhalla configuration. The demo bundles
  `assets/valhalla.json` and passes its contents to the API.
- A returned `GLMapRoute` owns native state. Release it with `close()` when no
  longer needed, including when its UI is removed. Repeated `close()` is safe.
- `updateLocation()` returns maneuver information, remaining distance/duration,
  progress and whether the position is on the route.
- Routes implement Core's `GLMapTrackSource`, allowing the optional Map package
  to draw retained route geometry.

The package does not provide a background navigation service or voice guidance.
See the [routing demos](../../example/lib/demo/routing_examples.dart) for road
routes, foreground GPS and reproducible tracking replay. Native SDK and map-data
license terms apply in addition to this package's [LICENSE](LICENSE).
