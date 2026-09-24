import Flutter
import GLMapCore
import GLMapCoreSwift

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

final class SdkBridge: CoreHostApi {
    private let registrar: FlutterPluginRegistrar
    private let events: SdkEventsApi
    private var observers: [NSObjectProtocol] = []
    private var cancels: [Int64: () -> Void] = [:]
    private let locale = GLMapLocaleSettings(localesOrder: ["en", "native"], unitSystem: .international)

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        events = SdkEventsApi(binaryMessenger: registrar.messenger())
        CoreHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: self)
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
    func cancelRequest(requestId: Int64) throws { cancels[requestId]?() }
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
    func detach() {
        CoreHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
        for cancel in cancels.values { cancel() }
        cancels.removeAll()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
    }
    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        for cancel in cancels.values { cancel() }
    }
}
