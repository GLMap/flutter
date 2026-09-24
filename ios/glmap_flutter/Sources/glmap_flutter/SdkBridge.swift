import Flutter
import GLMap
import GLMapCore
import GLMapSwift
import GLSearch
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

final class SdkBridge: SdkHostApi {
    private let registrar: FlutterPluginRegistrar
    private let events: SdkEventsApi
    private var observers: [NSObjectProtocol] = []
    private var cancels: [Int64: () -> Void] = [:]
    private(set) var routes: [Int64: GLRoute] = [:]
    private var trackers: [Int64: GLRouteTracker] = [:]
    private var nextRoute: Int64 = 0
    private let locale = GLMapLocaleSettings(localesOrder: ["en", "native"], unitSystem: .international)

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        events = SdkEventsApi(binaryMessenger: registrar.messenger())
        SdkHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: self)
        for name in [GLMapDownloadTask.downloadProgress, GLMapDownloadTask.downloadFinished] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let self, let task = note.object as? GLMapDownloadTask else { return }
                progress(id: task.map.mapID, kind: Int64(task.dataSet.rawValue), downloaded: Int64(task.downloaded), total: Int64(task.total), error: task.error?.localizedDescription, finished: name == GLMapDownloadTask.downloadFinished, area: false)
            })
        }
    }
    func initialize(apiKey: String) throws {
        guard GLMapManager.activate(apiKey: apiKey) else { throw featureError("GLMap initialization failed") }
        try restoreAreas()
    }
    func assetPath(_ asset: String) throws -> String {
        let key = registrar.lookupKey(forAsset: asset)
        guard let path = Bundle.main.path(forResource: key, ofType: nil) else { throw featureError("Asset unavailable: \(asset)") }
        return path
    }
    func addAssetDataSet(asset: String, dataSet: Int64) throws {
        guard (0...2).contains(dataSet) else { throw featureError("Invalid dataset type") }
        let kinds: [GLMapInfoDataSet] = [.map, .navigation, .elevation]
        if let error = GLMapManager.shared.add(kinds[Int(dataSet)], path: try assetPath(asset), bbox: .empty).nsError { throw error }
    }
    func place(_ object: GLMapVectorObject) -> PlaceMessage {
        PlaceMessage(name: object.localizedName(locale)?.asString() ?? "Unnamed place", detail: object.value(forKey: "search:secondaryText")?.asString() ?? "", point: GLMapGeoPoint(point: object.point).message)
    }
    private func region(_ id: Int64) throws -> GLMapInfo {
        guard let info = GLMapManager.shared.cachedMaps()?[NSNumber(value: id)] else { throw featureError("Unknown region \(id)") }
        return info
    }
    func regions(parent: Int64?, refresh: Bool, completion: @escaping (Result<[RegionMessage], Error>) -> Void) {
        let read = { [self] in
            completion(Result {
                let maps = try parent.map { try region($0).subMaps } ?? GLMapManager.shared.cachedMapList() ?? []
                return maps.map { RegionMessage(id: $0.mapID, name: $0.name(inLanguage: "en") ?? $0.name(), collection: !$0.subMaps.isEmpty, downloadedMask: Int64($0.dataSets(with: .downloaded).rawValue), downloadingMask: Int64($0.dataSets(with: .inProgress).rawValue), size: Int64($0.sizeOnServer(forDataSets: .all)), localSize: Int64($0.sizeOnDisk(forDataSets: .all))) }
            })
        }
        if refresh { GLMapManager.shared.updateMapList { _, _, error in if let error { completion(.failure(error)) } else { read() } } }
        else { read() }
    }
    func downloadRegion(id: Int64, mask: Int64) throws { GLMapManager.shared.downloadDataSets(GLMapInfoDataSetMask(rawValue: UInt8(mask)), forMap: try region(id), withCompletionBlock: nil) }
    func cancelRegionDownload(id: Int64) throws { GLMapManager.shared.downloadTasks(forMap: try region(id), dataSets: .all)?.forEach { $0.cancel() } }
    func deleteRegion(id: Int64, mask: Int64) throws { GLMapManager.shared.deleteDataSets(GLMapInfoDataSetMask(rawValue: UInt8(mask)), forMap: try region(id)) }
    func search(requestId: Int64, text: String, offline: Bool, autocomplete: Bool, center: GeoMessage, categories: [String], completion: @escaping (Result<[PlaceMessage], Error>) -> Void) {
        let request = GLSearchRequest(type: autocomplete ? .autocomplete : .search, text: text, center: center.native, limit: 30, locales: ["en", "native"], categories: categories)
        let callback: GLSearchResultsCompletionBlock = { [weak self] objects, error in
            guard let self else { return }
            cancels.removeValue(forKey: requestId)
            if let error { completion(.failure(error)) }
            else { completion(.success(objects.map { array in (0..<array.count).map { self.place(array[$0]) } } ?? [])) }
        }
        let id = offline ? request.startOffline(completion: callback) : request.startOnline(completion: callback)
        if id != 0 { cancels[requestId] = { GLSearchRequest.cancel(id) } }
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
        nextRoute += 1; routes[nextRoute] = route
        var coordinates: [Double] = []
        route.enumPoints(from: 0) { point, _ in let p = GLMapGeoPoint(point: point); coordinates.append(contentsOf: [p.lon, p.lat]) }
        return RouteMessage(id: nextRoute, distance: route.length, duration: route.duration, bounds: route.bbox.message, lonLat: doubles(coordinates))
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
    func cancelRequest(requestId: Int64) throws { cancels[requestId]?() }
    func updateNavigation(routeId: Int64, point: GeoMessage, bearing: Double) throws -> NavigationMessage {
        guard let route = routes[routeId] else { throw featureError("Route has been released") }
        if trackers[routeId] == nil { trackers[routeId] = GLRouteTracker(data: route); trackers[routeId]?.currentTargetPointIndex = 1 }
        guard let tracker = trackers[routeId] else { throw featureError("Cannot track route") }
        let maneuver = tracker.updateLocation(point.native, userBearing: Float(bearing))
        return NavigationMessage(instruction: maneuver?.shortInstruction ?? "", distanceToManeuver: tracker.distanceToNextManeuver, remainingDistance: tracker.remainingDistance, remainingDuration: tracker.remainingDuration, progress: tracker.progressIndex, onRoute: tracker.onRoute, point: GLMapGeoPoint(point: tracker.locationOnRoute).message)
    }
    func releaseRoute(routeId: Int64) throws { trackers.removeValue(forKey: routeId); routes.removeValue(forKey: routeId) }
    private func progress(id: Int64, kind: Int64, downloaded: Int64, total: Int64, error: String?, finished: Bool, area: Bool) {
        Task { @MainActor [events] in try? await events.downloadProgress(id: id, dataSet: kind, downloaded: downloaded, total: total, error: error, finished: finished, area: area) }
    }
    private let areaKinds: [GLMapInfoDataSet] = [.map, .navigation, .elevation]
    private let areaExtensions = ["vmtar", "navtar", "eletar"]
    private func areaDirectory() throws -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("glmap-areas", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    private func registerArea(_ kind: GLMapInfoDataSet, bounds: BoundsMessage, file: URL) throws {
        // The SDK returns EEXIST for duplicate registrations. Replace our own.
        GLMapManager.shared.remove(kind, path: file.path)
        if let error = GLMapManager.shared.add(kind, path: file.path, bbox: bounds.native).nsError { throw error }
    }
    private func restoreAreas() throws {
        // Final filenames retain the bounds. Interrupted .part files are ignored.
        for file in try FileManager.default.contentsOfDirectory(at: areaDirectory(), includingPropertiesForKeys: nil) {
            let parts = file.deletingPathExtension().lastPathComponent.split(separator: "_", omittingEmptySubsequences: false)
            let coordinates = parts.compactMap { Double($0) }
            if let kind = areaExtensions.firstIndex(of: file.pathExtension), parts.count == 4, coordinates.count == 4, coordinates.allSatisfy(\.isFinite) {
                try registerArea(areaKinds[kind], bounds: BoundsMessage(south: coordinates[0], west: coordinates[1], north: coordinates[2], east: coordinates[3]), file: file)
            }
        }
    }
    func downloadArea(requestId: Int64, bounds: BoundsMessage, mask: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        let kinds: [GLMapInfoDataSet] = [.map, .navigation, .elevation]
        let chosen = (0...2).filter { mask & (1 << $0) != 0 }
        guard !chosen.isEmpty else { completion(.failure(featureError("Choose a dataset"))); return }
        let group = DispatchGroup()
        var firstError: Error?
        var ids: [Int64] = []
        let root: URL
        do { root = try areaDirectory() }
        catch { completion(.failure(error)); return }
        cancels[requestId] = { ids.forEach { GLMapManager.shared.cancelDownload($0) } }
        for index in chosen {
            let file = root.appendingPathComponent("\(bounds.south)_\(bounds.west)_\(bounds.north)_\(bounds.east).\(areaExtensions[index])")
            if FileManager.default.fileExists(atPath: file.path) {
                do {
                    try registerArea(kinds[index], bounds: bounds, file: file)
                    let size = (try file.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
                    progress(id: requestId, kind: Int64(index), downloaded: Int64(size), total: Int64(size), error: nil, finished: true, area: true)
                } catch {
                    if firstError == nil { firstError = error }
                    progress(id: requestId, kind: Int64(index), downloaded: 0, total: 0, error: error.localizedDescription, finished: true, area: true)
                }
                continue
            }
            let partial = root.appendingPathComponent("\(UUID().uuidString).part")
            group.enter()
            ids.append(GLMapManager.shared.downloadDataSet(kinds[index], path: partial.path, bbox: bounds.native, progress: { [weak self] total, downloaded, _ in
                self?.progress(id: requestId, kind: Int64(index), downloaded: Int64(downloaded), total: Int64(total), error: nil, finished: false, area: true)
            }) { [weak self] error in
                defer { try? FileManager.default.removeItem(at: partial); group.leave() }
                do {
                    if let error { throw error }
                    if !FileManager.default.fileExists(atPath: file.path) { try FileManager.default.moveItem(at: partial, to: file) }
                    try self?.registerArea(kinds[index], bounds: bounds, file: file)
                    let size = (try file.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
                    self?.progress(id: requestId, kind: Int64(index), downloaded: Int64(size), total: Int64(size), error: nil, finished: true, area: true)
                } catch {
                    if firstError == nil { firstError = error }
                    self?.progress(id: requestId, kind: Int64(index), downloaded: 0, total: 0, error: error.localizedDescription, finished: true, area: true)
                }
            })
        }
        group.notify(queue: .main) { [weak self] in self?.cancels.removeValue(forKey: requestId); completion(firstError.map { .failure($0) } ?? .success(())) }
    }
    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        for cancel in cancels.values { cancel() }
    }
}
