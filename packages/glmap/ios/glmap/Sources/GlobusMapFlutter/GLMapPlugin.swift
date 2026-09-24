import Flutter
import UIKit
import GLMap
import GLMapCore
import GLMapSwift
import glmap_core

public class GLMapPluginImplementation: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let sdk = MapAssets(registrar: registrar)
        registrar.register(MapFactory(messenger: registrar.messenger(), sdk: sdk), withId: "glmap_lab")
    }
}

private final class MapFactory: NSObject, FlutterPlatformViewFactory {
    let messenger: FlutterBinaryMessenger
    let sdk: MapAssets
    init(messenger: FlutterBinaryMessenger, sdk: MapAssets) { self.messenger = messenger; self.sdk = sdk }
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        MapPlatformView(frame: frame, id: viewId, messenger: messenger, fixture: args as! [String: Any], sdk: sdk)
    }
}

private final class MapPlatformView: NSObject, FlutterPlatformView {
    private let resources: CoreResources
    private let id: Int64
    private var api: MapApiBridge!
    private var features: MapFeaturesBridge!
    private let map: GLMapView
    private let channel: FlutterMethodChannel
    private let track: GLMapVectorLayer
    private let marker: GLMapImage
    private var taps = 0
    private var moves = 0
    private var failure: String?

    init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger, fixture: [String: Any], sdk: MapAssets) {
        self.id = id
        self.resources = CoreResources.forMessenger(messenger)
        if fixture["trackJson"] != nil { GLMapManager.activate(apiKey: "") }
        map = GLMapView(frame: frame)
        track = GLMapVectorLayer(drawOrder: 1)
        marker = GLMapImage(drawOrder: 2)
        channel = FlutterMethodChannel(name: "glmap_lab/\(id)", binaryMessenger: messenger)
        super.init()
        map.isAccessibilityElement = true
        map.accessibilityIdentifier = "GLMap canvas"
        map.accessibilityLabel = "GLMap canvas"
        do {
            guard let path = GLMapManager.shared.resourcesBundle.path(forResource: "DefaultStyle", ofType: "bundle") else {
                throw NSError(domain: "GLMapLab", code: 1, userInfo: [NSLocalizedDescriptionKey: "GLMap style resource unavailable"])
            }
            let parser = GLMapStyleParser(paths: [path])
            map.setStyle(try parser.parseFromResources())
            map.reloadTiles()
            setCamera(fixture["camera"] as! [String: Any])
            let objects = try GLMapVectorObject.createVectorObjects(fromGeoJSON: (fixture["trackJson"] as? String ?? "{\"type\":\"FeatureCollection\",\"features\":[]}"))
            let style = GLMapVectorCascadeStyle.createStyle("line{width:4pt;color:#E74C3C;}")!
            track.setVectorObjects(objects, with: style, completion: nil)
            map.add(track)
            let point = fixture["marker"] as? [String: Any] ?? ["latitude": 0, "longitude": 0]
            let image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
                UIColor.white.setFill()
                context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 24, height: 24))
                UIColor(red: 38 / 255, green: 80 / 255, blue: 214 / 255, alpha: 1).setFill()
                context.cgContext.fillEllipse(in: CGRect(x: 3, y: 3, width: 18, height: 18))
            }
            marker.setImage(image, completion: nil)
            marker.position = GLMapPoint(lat: point.number("latitude"), lon: point.number("longitude"))
            marker.offset = CGPoint(x: image.size.width / 2, y: image.size.height / 2)
            if fixture["marker"] != nil { map.add(marker) }
        } catch { failure = error.localizedDescription }
        api = MapApiBridge(map: map, messenger: messenger, id: id, failure: failure)
        features = MapFeaturesBridge(map: map, sdk: sdk, resources: resources, messenger: messenger, id: id)
        resources.registerMap(id) { [weak map] reply in
            guard let map, map.window != nil else { reply(.failure(NSError(domain:"map_unavailable",code:1))); return }
            map.captureState { reply(.success($0)) }
        }
        map.tapGestureBlock = { [weak self] gesture in guard let self else { return }; taps += 1; features.tap(gesture.location(in: map), longPress: false) }
        map.longPressGestureBlock = { [weak self] gesture in guard let self, gesture.state == .began else { return }; features.tap(gesture.location(in: map), longPress: true) }
        map.mapDidMoveBlock = { [weak self] _ in self?.moves += 1 }
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { result(FlutterError(code: "disposed", message: "Map has been disposed", details: nil)); return }
            if let failure = self.failure { result(FlutterError(code: "initialization", message: failure, details: nil)); return }
            switch call.method {
            case "diagnostics":
                result(["latitude": self.map.mapGeoCenter.lat, "longitude": self.map.mapGeoCenter.lon,
                        "zoom": self.map.mapZoomLevel, "angle": self.map.mapAngle,
                        "taps": self.taps, "moves": self.moves,
                        "width": self.map.bounds.width, "height": self.map.bounds.height,
                        "surfaceAvailable": self.map.window != nil, "sdk": "local SDK draft",
                        "vectorLayers": self.api.vectorDiagnostics()])
            default: result(FlutterMethodNotImplemented)
            }
        }
    }

    private func setCamera(_ camera: [String: Any]) {
        map.mapGeoCenter = GLMapGeoPoint(lat: camera.number("latitude"), lon: camera.number("longitude"))
        map.mapZoomLevel = camera.number("zoom")
        map.mapAngle = 0
    }
    func view() -> UIView { map }
    deinit {
        resources.unregisterMap(id)
        features.dispose()
        api.dispose()
        channel.setMethodCallHandler(nil)
        map.tapGestureBlock = nil
        map.mapDidMoveBlock = nil
    }
}

private extension Dictionary where Key == String, Value == Any {
    func number(_ key: String) -> Double { (self[key] as! NSNumber).doubleValue }
}

@_cdecl("GlobusFlutterMapRegister")
public func registerMapPlugin(_ pointer: UnsafeMutableRawPointer) {
    let registrar=Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as! FlutterPluginRegistrar
    GLMapPluginImplementation.register(with:registrar)
}
