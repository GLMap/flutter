import Flutter
import glmap_core
import GLMapCore
import GLMapCoreSwift
import GLRoute

extension GeoMessage {
    var native: GLMapGeoPoint { GLMapGeoPoint(lat: latitude, lon: longitude) }
}
extension GLMapGeoPoint {
    var message: GeoMessage { GeoMessage(latitude: lat, longitude: lon) }
}
extension BoundsMessage {
    var native: GLMapBBox {
        var box = GLMapBBox.empty
        box.add(point: GLMapPoint(lat: south, lon: west)); box.add(point: GLMapPoint(lat: north, lon: east))
        return box
    }
}
extension GLMapBBox {
    var message: BoundsMessage {
        let a = GLMapGeoPoint(point: origin)
        let b = GLMapGeoPoint(point: GLMapPoint(x: origin.x + size.x, y: origin.y + size.y))
        return BoundsMessage(south: min(a.lat, b.lat), west: min(a.lon, b.lon), north: max(a.lat, b.lat), east: max(a.lon, b.lon))
    }
}
func featureError(_ message: String) -> FeatureError { FeatureError(code: "sdk_error", message: message, details: nil) }
func doubles(_ values: [Double]) -> FlutterStandardTypedData { values.withUnsafeBytes { FlutterStandardTypedData(float64: Data($0)) } }

final class ServiceBridge: RouteHostApi {
    private let messenger: FlutterBinaryMessenger
    private let resources: CoreResources
    private var cancels:[Int64:()->Void]=[:]
    private var routes:[Int64:GLRoute]=[:]
    private var trackers:[Int64:GLRouteTracker]=[:]
    init(messenger: FlutterBinaryMessenger) {
        self.messenger=messenger; resources=CoreResources.forMessenger(messenger)
        RouteHostApiSetup.setUp(binaryMessenger:messenger,api:self)
    }
    func route(requestId: Int64, start: GeoMessage, end: GeoMessage, mode: String, offline: Bool, offlineConfig: String?, completion: @escaping (Result<RouteMessage, Error>) -> Void) {
        let request = GLRouteRequest()
        switch mode {
        case "car": request.setAutoWithOptions(.default)
        case "bicycle": request.setBicycleWithOptions(.default)
        case "pedestrian": request.setPedestrianWithOptions(.default)
        default: completion(.failure(featureError("Invalid route mode"))); return
        }
        request.locale = "en-US"
        request.add(GLRoutePoint(pt: start.native, heading: .nan, type: .break))
        request.add(GLRoutePoint(pt: end.native, heading: .nan, type: .break))
        let callback: GLRouteRequestCompletionBlock = { [weak self] route, error in
            guard let self else { return }
            cancels.removeValue(forKey: requestId)
            guard let route else { completion(.failure(error ?? featureError("No route returned"))); return }
            completion(.success(store(route)))
        }
        do {
            if offline && offlineConfig == nil { throw featureError("Offline routing requires a Valhalla configuration") }
            let id = offline ? request.startOffline(withConfig: offlineConfig!, completion: callback) : request.startOnline(completion: callback)
            if id != 0 { cancels[requestId] = { GLRouteRequest.cancel(id) } }
        } catch { completion(.failure(error)) }
    }
    private func store(_ route: GLRoute) -> RouteMessage {
        let id = resources.addTrackSource { color in route.trackData(with: color) }; routes[id] = route
        var coordinates: [Double] = []
        route.enumPoints(from: 0) { point, _ in let p = GLMapGeoPoint(point: point); coordinates.append(contentsOf: [p.lon, p.lat]) }
        return RouteMessage(id: id, distance: route.length, duration: route.duration, bounds: route.bbox.message, lonLat: doubles(coordinates))
    }
    func buildRoute(steps: [RouteStepMessage]) throws -> RouteMessage {
        guard !steps.isEmpty else { throw featureError("Route needs steps") }
        let arrays = steps.map { $0.lonLat.data.withUnsafeBytes { Array($0.bindMemory(to: Double.self)) } }
        guard arrays.allSatisfy({ $0.count >= 4 && $0.count % 2 == 0 && $0.allSatisfy(\.isFinite) }), steps.allSatisfy({ (0...2).contains($0.turn) && $0.duration.isFinite && $0.duration >= 0 }) else { throw featureError("Invalid route steps") }
        let builder = GLRouteBuilder(); builder.setLanguage("en")
        let a = arrays.first!, b = arrays.last!
        builder.addTargetPoint(GLRoutePoint(pt: GLMapGeoPoint(lat: a[1], lon: a[0]), heading: .nan, type: .break))
        builder.addTargetPoint(GLRoutePoint(pt: GLMapGeoPoint(lat: b[b.count-1], lon: b[b.count-2]), heading: .nan, type: .break))
        let turns: [GLManeuverType] = [.continue, .right, .left]
        for (index, step) in steps.enumerated() {
            let values = arrays[index]
            let points = stride(from: 0, to: values.count, by: 2).map { GLMapPoint(lat: values[$0+1], lon: values[$0]) }
            points.withUnsafeBufferPointer { builder.add(turns[Int(step.turn)], points: $0.baseAddress!, heights: nil, numberOfPoints: UInt32($0.count)) }
            builder.setManeuverShortInstruction(step.instruction); builder.setManeuverTime(step.duration)
        }
        var finish = GLMapPoint(lat: b[b.count-1], lon: b[b.count-2])
        builder.add(.destination, points: &finish, heights: nil, numberOfPoints: 1)
        builder.setManeuverShortInstruction("Arrive at destination")
        guard let route = builder.build() else { throw featureError("Cannot build route") }
        return store(route)
    }
    func updateNavigation(routeId: Int64, point: GeoMessage, bearing: Double) throws -> NavigationMessage {
        guard let route = routes[routeId] else { throw featureError("Route has been released") }
        if trackers[routeId] == nil { trackers[routeId] = GLRouteTracker(data: route); trackers[routeId]?.currentTargetPointIndex = 1 }
        guard let tracker = trackers[routeId] else { throw featureError("Cannot track route") }
        let maneuver = tracker.updateLocation(point.native, userBearing: Float(bearing))
        return NavigationMessage(instruction: maneuver?.shortInstruction ?? "", distanceToManeuver: tracker.distanceToNextManeuver, remainingDistance: tracker.remainingDistance, remainingDuration: tracker.remainingDuration, progress: tracker.progressIndex, onRoute: tracker.onRoute, point: GLMapGeoPoint(point: tracker.locationOnRoute).message)
    }
    func releaseRoute(routeId: Int64) throws { resources.removeTrackSource(routeId); trackers.removeValue(forKey: routeId); routes.removeValue(forKey: routeId) }
    func cancelRequest(requestId:Int64) throws { cancels[requestId]?() }
    func detach() {
        RouteHostApiSetup.setUp(binaryMessenger:messenger,api:nil)
        let pending=cancels; cancels.removeAll(); pending.values.forEach { $0() }
        for id in routes.keys { resources.removeTrackSource(id) }; trackers.removeAll(); routes.removeAll()
    }
}
