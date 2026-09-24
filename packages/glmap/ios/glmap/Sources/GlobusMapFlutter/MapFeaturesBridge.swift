import Flutter
import UIKit
import GLMap
import GLMapCore
import GLMapSwift
import BulkGeometry
import glmap_core

private final class ImageGroupSource: GLMapImageGroupDataSource {
    let points: [GLMapPoint]
    let image: UIImage
    init(points: [GeoMessage], image: UIImage) { self.points = points.map { GLMapPoint(geoPoint: $0.native) }; self.image = image }
    func startUpdate() {}
    func endUpdate() {}
    func getVariantsCount() -> UInt32 { 1 }
    func getVariant(_ index: UInt32, offset: UnsafeMutablePointer<CGPoint>) -> UIImage { offset.pointee = CGPoint(x: image.size.width / 2, y: image.size.height / 2); return image }
    func getImagesCount() -> UInt32 { UInt32(points.count) }
    func getImageInfo(_ index: UInt32, variant: UnsafeMutablePointer<UInt32>, position: UnsafeMutablePointer<GLMapPoint>) { variant.pointee = 0; position.pointee = points[Int(index)] }
}

private final class RasterSource: GLMapRasterTileSource {
    let template: String
    init?(template: String, attribution: String) {
        self.template = template
        super.init(cachePath: nil)
        validZoomMask = (1 << 20) - 1
        attributionText = attribution
    }
    override func url(for pos: GLMapTilePos) -> URL? {
        URL(string: template.replacingOccurrences(of: "{z}", with: String(pos.z)).replacingOccurrences(of: "{x}", with: String(pos.x)).replacingOccurrences(of: "{y}", with: String(pos.y)))
    }
}

final class MapFeaturesBridge: MapFeaturesHostApi {
    private weak var map: GLMapView?
    private let sdk: MapAssets
    private let resources: CoreResources
    private let messenger: FlutterBinaryMessenger
    private let suffix: String
    private let events: MapEventsApi
    private var objects: [Int64: [GLMapDrawObject]] = [:]
    private var retained: [Int64: [AnyObject]] = [:]
    private var routeIds: [Int64: Int64] = [:]
    init(map: GLMapView, sdk: MapAssets, resources: CoreResources, messenger: FlutterBinaryMessenger, id: Int64) {
        self.map = map; self.sdk = sdk; self.resources = resources; self.messenger = messenger; suffix = String(id)
        events = MapEventsApi(binaryMessenger: messenger, messageChannelSuffix: String(id))
        MapFeaturesHostApiSetup.setUp(binaryMessenger: messenger, api: self, messageChannelSuffix: suffix)
    }
    private func active() throws -> GLMapView { guard let map else { throw featureError("Map has been removed") }; return map }
    func tap(_ point: CGPoint, longPress: Bool) {
        guard let map else { return }
        let geo = GLMapGeoPoint(point: map.makeMapPoint(fromDisplay: point)).message
        Task { @MainActor [events] in try? await events.tap(point: geo, x: point.x, y: point.y, longPress: longPress) }
    }
    private func replace(_ id: Int64, _ values: [GLMapDrawObject], keep: [AnyObject] = []) throws {
        let map = try active(); try removeObject(id: id)
        objects[id] = values; retained[id] = keep
        values.forEach { map.add($0) }
    }
    func removeObject(id: Int64) throws { objects.removeValue(forKey: id)?.forEach { map?.remove($0) }; retained.removeValue(forKey: id); routeIds.removeValue(forKey: id) }
    func setStyleOptions(options: [String: String], assetDirectory: String?) throws {
        let map = try active()
        guard let path = GLMapManager.shared.resourcesBundle.path(forResource: "DefaultStyle", ofType: "bundle") else { throw featureError("Style unavailable") }
        let paths = try [path] + (assetDirectory.map { [try sdk.assetPath($0)] } ?? [])
        let parser = GLMapStyleParser(paths: paths); parser.setOptions(options, defaultValue: true)
        map.setStyle(try parser.parseFromResources()); map.reloadTiles()
    }
    func setTerrain(altitudeScale: Double, hillshades: Bool, contours: Bool, slopes: Bool) throws {
        guard altitudeScale.isFinite, (0...10).contains(altitudeScale) else { throw featureError("Invalid altitude scale") }
        let map = try active(); map.altitudeScale = Float(altitudeScale); map.drawHillshades = hillshades; map.drawElevationLines = contours; map.drawSlopes = slopes
    }
    func setOnlineTiles(enabled: Bool) throws { GLMapManager.shared.tileDownloadingAllowed = enabled; try active().reloadTiles() }
    func setRasterSource(urlTemplate: String?, attribution: String) throws {
        let map = try active()
        if let template = urlTemplate {
            guard template.hasPrefix("https://"), ["{z}", "{x}", "{y}"].allSatisfy(template.contains), let source = RasterSource(template: template, attribution: attribution) else { throw featureError("Invalid XYZ tile URL") }
            map.base = source
        } else { map.base = GLMapVectorTileSource() }
        map.reloadTiles()
    }
    func animateCamera(center: GeoMessage, zoom: Double, duration: Double, fly: Bool) throws {
        let map = try active()
        guard duration.isFinite, duration >= 0, zoom.isFinite else { throw featureError("Invalid animation") }
        map.animate { animation in animation.duration = duration; animation.flyToMode = fly ? .enabled : .disabled; map.mapGeoCenter = center.native; map.mapZoomLevel = zoom }
    }
    func fitBounds(bounds: BoundsMessage) throws { let map = try active(); let box = bounds.native; map.mapCenter = box.center; map.mapScale = map.mapScale(for: box) }
    private func image(_ data: FlutterStandardTypedData) throws -> UIImage { guard let image = UIImage(data: data.data) else { throw featureError("Expected PNG image") }; return image }
    func setImage(id: Int64, point: GeoMessage, png: FlutterStandardTypedData) throws {
        let image = try image(png); let pin = GLMapImage(drawOrder: 3)
        pin.setImage(image, completion: nil); pin.offset = CGPoint(x: image.size.width / 2, y: image.size.height / 2); pin.position = GLMapPoint(geoPoint: point.native)
        try replace(id, [pin])
    }
    func setImageGroup(id: Int64, points: [GeoMessage], png: FlutterStandardTypedData) throws {
        let source = ImageGroupSource(points: points, image: try image(png))
        try replace(id, [GLMapImageGroup(callback: source, andDrawOrder: 3)], keep: [source])
    }
    func setMarkers(id: Int64, geoJson: String, png: FlutterStandardTypedData, clusteringRadius: Double) throws {
        guard clusteringRadius.isFinite, clusteringRadius >= 0 else { throw featureError("Invalid clustering radius") }
        let objects = try GLMapVectorObject.createVectorObjects(fromGeoJSON: geoJson)
        let styles = GLMapMarkerStyleCollection(); styles.addStyle(with: try image(png))
        guard let textStyle = GLMapVectorStyle.createStyle("{text-color:black;font-size:13;font-stroke-width:1pt;font-stroke-color:white;}") else { throw featureError("Invalid marker style") }
        styles.setMarkerDataFill { _, data in data.setStyle(0) }
        styles.setMarkerUnionFill { count, data in data.setStyle(0); data.setText("\(count)", offset: .zero, style: textStyle) }
        let layer = GLMapMarkerLayer(vectorObjects: objects, andStyles: styles, clusteringRadius: clusteringRadius, drawOrder: 3)
        try replace(id, [layer], keep: [objects, styles, textStyle])
    }
    func setBalloon(id: Int64, point: GeoMessage, text: String) throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 60)).image { _ in UIColor.white.setFill(); UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 80, height: 60), cornerRadius: 12).fill() }
        let balloon = GLMapBalloon(drawOrder: 8)
        guard let style = GLMapVectorStyle.createStyle("{text-color:#172B4D;font-size:15;}") else { throw featureError("Invalid text style") }
        balloon.setBackgroundImage(image, insets: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20))
        balloon.setText(text, with: style, insets: UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12), completion: nil)
        balloon.position = GLMapPoint(geoPoint: point.native)
        try replace(id, [balloon])
    }
    func setTrack(id: Int64, lonLat: FlutterStandardTypedData, progress: Double, arrows: Bool) throws {
        let values = lonLat.data.withUnsafeBytes { Array($0.bindMemory(to: Double.self)) }
        guard values.count >= 4, values.count % 2 == 0 else { throw featureError("A track needs two points") }
        let color = GLMapColor(red: 39, green: 100, blue: 225, alpha: 255)
        guard let data = GLMapTrackData(pointsCallback: { index, point in point.pointee = GLTrackPoint(pt: GLMapPoint(lat: values[Int(index)*2+1], lon: values[Int(index)*2]), color: color); return true }, count: UInt(values.count/2), reverse: false),
              let style = GLMapVectorStyle.createStyle(arrows ? "{width:14pt;fill-image:\"track-arrow.svg\";}" : "{width:7pt;}") else { throw featureError("Invalid track") }
        let track = GLMapTrack(drawOrder: 4); track.setData(data, style: style, completion: nil)
        track.progressColor = GLMapColor(red: 128, green: 128, blue: 128, alpha: 255); track.progressIndex = progress
        var draw: [GLMapDrawObject] = [track]; var keep: [AnyObject] = [data, style]
        if arrows {
            let source = values.withUnsafeBufferPointer { GLMapLabBuildPacked($0.baseAddress!, $0.count) }
            if let source, let line = source[0] as? GLMapVectorLine {
                let head = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { _ in
                    UIColor.systemGreen.setFill(); let path = UIBezierPath(); path.move(to: CGPoint(x: 20,y: 0)); path.addLine(to: CGPoint(x: 40,y: 40)); path.addLine(to: CGPoint(x: 20,y: 30)); path.addLine(to: CGPoint(x: 0,y: 40)); path.close(); path.fill()
                }
                let arrow = GLMapLineArrow(drawOrder: 5); arrow.setLineStyle(style, head: head); arrow.setLine(line, index: UInt32(values.count/4))
                draw.append(arrow); keep.append(source)
            }
        }
        try replace(id, draw, keep: keep)
    }
    func setRouteTrack(id: Int64, routeId: Int64, progress: Double) throws {
        if routeIds[id] == routeId, let track = objects[id]?.first as? GLMapTrack, resources.containsTrack(routeId) {
            track.progressIndex = progress
            return
        }
        guard let data = resources.trackData(routeId, color: GLMapColor(red: 20, green: 180, blue: 100, alpha: 255)), let style = GLMapVectorStyle.createStyle("{width:8pt;}") else { throw featureError("Route unavailable") }
        let old: GLMapTrack? = objects[id]?.count == 1 ? (objects[id]?.first as? GLMapTrack) : nil
        let track = old ?? GLMapTrack(drawOrder: 4)
        track.setData(data, style: style, completion: nil); track.progressColor = GLMapColor(red: 128, green: 128, blue: 128, alpha: 255); track.progressIndex = progress
        if old == nil { try replace(id, [track], keep: [data, style]) } else { retained[id] = [data, style] }
        routeIds[id] = routeId
    }
    func project(points: [GeoMessage], completion: @escaping (Result<FlutterStandardTypedData, Error>) -> Void) {
        do { try active().captureState { state in
            completion(.success(doubles(points.flatMap { point in let p = state.makeDisplayPoint(from: GLMapPoint(geoPoint: point.native), elevation: 0); return [Double(p.x), Double(p.y)] })))
        } } catch { completion(.failure(error)) }
    }
    func dispose() {
        objects.values.flatMap { $0 }.forEach { map?.remove($0) }; objects.removeAll(); retained.removeAll(); map = nil
        MapFeaturesHostApiSetup.setUp(binaryMessenger: messenger, api: nil, messageChannelSuffix: suffix)
    }
}
