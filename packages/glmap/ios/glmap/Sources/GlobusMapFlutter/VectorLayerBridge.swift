import Flutter
import BulkGeometry
import GLMap
import GLMapCore
import GLMapSwift

/// Retains the accepted native geometry for restyle; native code owns update outcomes.
final class VectorLayerBridge {
    let layer: GLMapVectorLayer
    private var objects: GLMapVectorObjectArray?

    init(drawOrder: Int32) { layer = GLMapVectorLayer(drawOrder: drawOrder) }

    func update(_ mutation: VectorMutationMessage, completion: @escaping (Result<VectorReply, Error>) -> Void) throws {
        guard let source = mutation.style else { throw error("invalid_style", "MapCSS is required") }
        let style: GLMapVectorCascadeStyle
        do {
            let parser = GLMapStyleParser()
            try parser.parseNextString(source)
            style = try parser.finish()
        } catch { throw self.error("invalid_style", error.localizedDescription) }

        let next: GLMapVectorObjectArray
        if mutation.operation == .replace {
            next = try geometry(mutation)
        } else {
            guard let objects else { throw error("missing_geometry", "Call replace before setStyle") }
            next = objects
        }
        layer.setVectorObjects(next, with: style, completion: { result in
            let reply: VectorReply
            switch result {
            case .ready: reply = .ready
            case .superseded: reply = .superseded
            case .cancelled: reply = .cancelled
            case .failed: reply = .failed
            @unknown default:
                completion(.failure(MapApiError(code: "native_result", message: "Unknown vector update result", details: nil)))
                return
            }
            completion(.success(reply))
        })
        objects = next
    }

    private func geometry(_ mutation: VectorMutationMessage) throws -> GLMapVectorObjectArray {
        guard (mutation.lonLat == nil) != (mutation.geoJson == nil) else {
            throw error("invalid_geometry", "Specify packed coordinates or GeoJSON")
        }
        if let json = mutation.geoJson {
            do { return try GLMapVectorObject.createVectorObjects(fromGeoJSON: json) }
            catch { throw self.error("invalid_geometry", error.localizedDescription) }
        }
        return try mutation.lonLat!.data.withUnsafeBytes { bytes in
            let values = bytes.bindMemory(to: Double.self)
            guard values.count % 2 == 0, values.count != 2 else {
                throw error("invalid_geometry", "A line needs zero or at least two points")
            }
            if values.isEmpty { return GLMapVectorObjectArray() }
            guard let address = values.baseAddress, let result = GLMapFlutterBuildPacked(address, values.count) else {
                throw error("invalid_geometry", "Invalid packed line")
            }
            return result
        }
    }

    func pick(point: GLMapPoint, tolerance: Double) -> String? {
        guard let objects else { return nil }
        // Match Android's findNearPoint(0, count): first matching input feature wins.
        for index in 0..<objects.count {
            var nearest = point
            let object = objects[index]
            if object.findNearestPoint(&nearest, to: point, maxDistance: tolerance) { return object.asGeoJSON() }
        }
        return nil
    }

    // Readback from actual native input objects, not from Dart arguments.
    func diagnostics(id: Int64) -> [String: Any] {
        var result: [String: Any] = ["id": id, "objectCount": objects?.count ?? 0]
        if let objects, objects.count > 0 {
            let box = objects.bbox
            result["bounds"] = [box.origin.x, box.origin.y, box.size.x, box.size.y]
        }
        return result
    }

    private func error(_ code: String, _ message: String) -> MapApiError {
        MapApiError(code: code, message: message, details: nil)
    }
}
