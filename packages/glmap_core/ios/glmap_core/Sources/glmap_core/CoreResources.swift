import Flutter
import GLMapCore

/// Engine-scoped ownership/handoff of existing native SDK resources. Main queue only.
public final class CoreResources {
    private static var engines:[ObjectIdentifier:CoreResources]=[:]
    public static func forMessenger(_ messenger:FlutterBinaryMessenger)->CoreResources {
        let key=ObjectIdentifier(messenger as AnyObject)
        if let value=engines[key] { return value }
        let value=CoreResources(); engines[key]=value; return value
    }
    public static func release(_ messenger:FlutterBinaryMessenger) {
        engines.removeValue(forKey:ObjectIdentifier(messenger as AnyObject))?.clear()
    }
    private var nextId:Int64=0
    private var tracks:[Int64:(GLMapColor)->GLMapTrackData?]=[:]
    private final class MapEntry {
        let capture: (@escaping (Result<GLMapViewState,Error>)->Void)->Void
        var pending:[Int64:(Result<GLMapViewState,Error>)->Void]=[:]
        init(_ capture:@escaping (@escaping (Result<GLMapViewState,Error>)->Void)->Void) { self.capture=capture }
    }
    private var maps:[Int64:MapEntry]=[:]
    public func addTrackSource(_ source:@escaping (GLMapColor)->GLMapTrackData?)->Int64 {
        nextId += 1; tracks[nextId]=source; return nextId
    }
    public func removeTrackSource(_ id:Int64) { tracks.removeValue(forKey:id) }
    public func trackData(_ id:Int64,color:GLMapColor)->GLMapTrackData? { tracks[id]?(color) }
    public func containsTrack(_ id:Int64)->Bool { tracks[id] != nil }
    public func registerMap(_ id:Int64,capture:@escaping (@escaping (Result<GLMapViewState,Error>)->Void)->Void) {
        unregisterMap(id); maps[id]=MapEntry(capture)
    }
    public func unregisterMap(_ id:Int64) {
        guard let entry=maps.removeValue(forKey:id) else { return }
        let waiting=entry.pending; entry.pending.removeAll()
        for reply in waiting.values { reply(.failure(NSError(domain:"map_disposed",code:1))) }
    }
    public func capture(_ id:Int64,reply:@escaping (Result<GLMapViewState,Error>)->Void) {
        guard let entry=maps[id] else { reply(.failure(NSError(domain:"map_disposed",code:1))); return }
        nextId += 1; let request=nextId; entry.pending[request]=reply
        entry.capture { result in
            DispatchQueue.main.async { entry.pending.removeValue(forKey:request)?(result) }
        }
    }
    private func clear() { for id in Array(maps.keys) { unregisterMap(id) }; tracks.removeAll() }
}
