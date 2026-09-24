import Flutter
import glmap_core
import GLMapCore
import GLMapCoreSwift
import GLSearch

extension GeoMessage {
    var native: GLMapGeoPoint { GLMapGeoPoint(lat: latitude, lon: longitude) }
}
extension GLMapGeoPoint {
    var message: GeoMessage { GeoMessage(latitude: lat, longitude: lon) }
}
func featureError(_ message: String) -> FeatureError { FeatureError(code: "sdk_error", message: message, details: nil) }
func doubles(_ values: [Double]) -> FlutterStandardTypedData { values.withUnsafeBytes { FlutterStandardTypedData(float64: Data($0)) } }

final class ServiceBridge: SearchHostApi {
    private let messenger: FlutterBinaryMessenger
    private let resources: CoreResources
    private var cancels:[Int64:()->Void]=[:]
    private let locale = GLMapLocaleSettings(localesOrder:["en","native"],unitSystem:.international)
    init(messenger: FlutterBinaryMessenger) {
        self.messenger=messenger; resources=CoreResources.forMessenger(messenger)
        SearchHostApiSetup.setUp(binaryMessenger:messenger,api:self)
    }
    func place(_ object: GLMapVectorObject) -> PlaceMessage {
        PlaceMessage(name: object.localizedName(locale)?.asString() ?? "Unnamed place", detail: object.value(forKey: "search:secondaryText")?.asString() ?? "", point: GLMapGeoPoint(point: object.point).message)
    }
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
    func pickObject(viewId: Int64, x: Double, y: Double, completion: @escaping (Result<PlaceMessage?, Error>) -> Void) {
        resources.capture(viewId) { [weak self] result in
            guard let self else { return }
            completion(result.map { state in state.mapObject(at: CGPoint(x:x,y:y),maxDistance:24).map(self.place) }.mapError { FeatureError(code:($0 as NSError).domain,message:$0.localizedDescription,details:nil) })
        }
    }
    func cancelRequest(requestId:Int64) throws { cancels[requestId]?() }
    func detach() {
        SearchHostApiSetup.setUp(binaryMessenger:messenger,api:nil)
        let pending=cancels; cancels.removeAll(); pending.values.forEach { $0() }
    }
}
