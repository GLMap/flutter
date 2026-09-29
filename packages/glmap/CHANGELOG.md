## 0.1.0-beta.1

- Pin the released native GLMap 2.2.0 artifacts on Android and iOS; rebuild the
  native app when updating. Preserve status-bearing vector completions.

- Add a native map widget and typed camera control/state snapshots.
- Support gestures, vector geometry, hit testing and map-owned drawing handles.
- Settle pending operations when a map is removed and reject invalid handle use.
- Use generated per-view Pigeon channels for native diagnostics and the same
  controller-owned cancellation/disposal rules as other map operations.
- Depend only on `glmap_core`; Search and Route remain optional.
