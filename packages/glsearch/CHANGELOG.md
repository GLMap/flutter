## 0.1.0-beta.1

- Pin the released native GLSearch 2.2.0 artifacts on Android and iOS; rebuild
  the native app and initialize Core before using Search.

- Add online/offline text search, category filters and autocomplete.
- Support cancellation and queries of objects on an optional displayed map.
- Depend only on `glmap_core`; text search works without a map renderer.
