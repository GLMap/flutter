import 'package:glmap_core/glmap_core.dart';
import 'package:flutter/widgets.dart' show Offset;

import 'src/search.g.dart';

export 'package:glmap_core/glmap_core.dart';

GeoMessage _geo(GLMapGeoPoint p) {
  p.validate();
  return GeoMessage(latitude: p.latitude, longitude: p.longitude);
}

GLMapPlace _place(PlaceMessage p) => GLMapPlace(
  name: p.name,
  detail: p.detail,
  point: GLMapGeoPoint(
    latitude: p.point.latitude,
    longitude: p.point.longitude,
  ),
);

class GLSearch {
  static final _api = SearchHostApi();
  static int _nextRequest = 0;
  static GLMapRequest<List<GLMapPlace>> search(
    String text, {
    required GLMapGeoPoint center,
    bool offline = true,
    bool autocomplete = false,
    List<String> categories = const [],
  }) {
    final id = ++_nextRequest;
    return GLMapRequest(
      id,
      _api
          .search(id, text, offline, autocomplete, _geo(center), categories)
          .then((items) => items.map(_place).toList(growable: false)),
      () => _api.cancelRequest(id),
    );
  }

  static Future<GLMapPlace?> pickObject(
    GLMapQueryTarget map,
    Offset point,
  ) async {
    final hit = await _api.pickObject(map.viewId, point.dx, point.dy);
    return hit == null ? null : _place(hit);
  }
}

extension GLSearchMapQueries on GLMapQueryTarget {
  Future<GLMapPlace?> pickObject(Offset point) =>
      GLSearch.pickObject(this, point);
}
