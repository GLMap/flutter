import Flutter
import GLMap
import GLMapCore
import UIKit

/// Owns Flutter replies, while the existing GLMapView owns native rendering.
final class MapApiBridge: MapHostApi {
    private weak var map: GLMapView?
    private let messenger: FlutterBinaryMessenger
    private let suffix: String
    private let initializationFailure: String?
    private var nextRequest = 0
    private var captures: [Int: CheckedContinuation<MapStateMessage, Error>] = [:]
    private var nextLayer: Int64 = 0
    private var layers: [Int64: VectorLayerBridge] = [:]

    init(map: GLMapView, messenger: FlutterBinaryMessenger, id: Int64, failure: String?) {
        self.map = map
        self.messenger = messenger
        self.suffix = String(id)
        self.initializationFailure = failure
        MapHostApiSetup.setUp(binaryMessenger: messenger, api: self, messageChannelSuffix: suffix)
    }

    private func ownedMap() throws -> GLMapView {
        guard let map else { throw error("map_disposed", "The map has been removed") }
        if let initializationFailure { throw error("initialization", initializationFailure) }
        return map
    }

    private func activeMap() throws -> GLMapView {
        let map = try ownedMap()
        guard map.window != nil, map.bounds.width > 0, map.bounds.height > 0 else {
            throw error("map_unavailable", "The map is not attached to a surface")
        }
        return map
    }

    func captureState() async throws -> MapStateMessage {
        try await withCheckedThrowingContinuation { continuation in
            // Pigeon's async call can enter a nonisolated async function on another executor.
            DispatchQueue.main.async { [self] in
                do {
                    let map = try activeMap()
                    let request = nextRequest
                    nextRequest += 1
                    captures[request] = continuation
                    map.captureState { [weak self] state in
                        let center = state.geoCenter
                        let value = MapStateMessage(latitude: center.lat, longitude: center.lon,
                            zoom: state.zoom, scale: state.scale, angle: Double(state.angle),
                            pitch: Double(state.pitch), originX: state.origin.x, originY: state.origin.y)
                        self?.captures.removeValue(forKey: request)?.resume(returning: value)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func setCamera(camera: MapCameraMessage) throws {
        let map = try activeMap()
        guard [camera.latitude, camera.longitude, camera.zoom, camera.angle, camera.pitch].allSatisfy({ $0.isFinite }),
              (-90...90).contains(camera.latitude), (-180...180).contains(camera.longitude),
              (0...45).contains(camera.pitch), Float(camera.angle).isFinite else {
            throw error("invalid_argument", "Invalid camera coordinates or angles")
        }
        map.mapGeoCenter = GLMapGeoPoint(lat: camera.latitude, lon: camera.longitude)
        map.mapZoomLevel = camera.zoom
        map.mapAngle = Float(camera.angle)
        map.mapPitch = Float(camera.pitch)
    }

    func createVectorLayer(drawOrder: Int64, completion: @escaping (Result<Int64, Error>) -> Void) {
        do {
            let map = try ownedMap()
            guard let order = Int32(exactly: drawOrder) else { throw error("invalid_argument", "drawOrder must fit int32") }
            let entry = VectorLayerBridge(drawOrder: order)
            nextLayer += 1
            layers[nextLayer] = entry
            map.add(entry.layer)
            completion(.success(nextLayer))
        } catch { completion(.failure(error)) }
    }

    func mutateVectorLayer(mutation: VectorMutationMessage, completion: @escaping (Result<VectorReply, Error>) -> Void) {
        do {
            let map = try ownedMap()
            guard let entry = layers[mutation.layerId] else { throw error("layer_removed", "Unknown or removed layer") }
            if mutation.operation == .remove {
                layers.removeValue(forKey: mutation.layerId)
                map.remove(entry.layer)
                completion(.success(.removed))
            } else {
                try entry.update(mutation, completion: completion)
            }
        } catch { completion(.failure(error)) }
    }

    func pickVectorFeature(layerId: Int64, x: Double, y: Double, tolerance: Double, completion: @escaping (Result<String?, Error>) -> Void) {
        do {
            guard x.isFinite, y.isFinite, tolerance.isFinite, tolerance >= 0 else { throw error("invalid_argument", "Invalid hit-test coordinates") }
            let map = try activeMap()
            guard let layer = layers[layerId] else { throw error("layer_removed", "Unknown or removed layer") }
            let point = map.makeMapPoint(fromDisplay: CGPoint(x: x, y: y))
            let delta = map.makeMapPoint(fromDisplayDelta: CGPoint(x: 0, y: tolerance))
            completion(.success(layer.pick(point: point, tolerance: hypot(delta.x, delta.y))))
        } catch { completion(.failure(error)) }
    }

    func vectorDiagnostics() -> [[String: Any]] {
        layers.sorted { $0.key < $1.key }.map { $0.value.diagnostics(id: $0.key) }
    }

    func dispose() {
        for entry in layers.values { map?.remove(entry.layer) }
        layers.removeAll()
        map = nil
        let waiting = captures
        captures.removeAll()
        for continuation in waiting.values {
            continuation.resume(throwing: error("map_disposed", "The map has been removed"))
        }
        MapHostApiSetup.setUp(binaryMessenger: messenger, api: nil, messageChannelSuffix: suffix)
    }

    private func error(_ code: String, _ message: String) -> MapApiError {
        MapApiError(code: code, message: message, details: nil)
    }
}
