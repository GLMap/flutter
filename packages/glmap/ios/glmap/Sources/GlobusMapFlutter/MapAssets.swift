import Flutter
import GLMapCore
import GLMapCoreSwift
extension GeoMessage { var native:GLMapGeoPoint { GLMapGeoPoint(lat:latitude,lon:longitude) } }
extension GLMapGeoPoint { var message:GeoMessage { GeoMessage(latitude:lat,longitude:lon) } }
extension BoundsMessage { var native:GLMapBBox {
    var box=GLMapBBox.empty;box.add(point:GLMapPoint(lat:south,lon:west));box.add(point:GLMapPoint(lat:north,lon:east));return box
} }
func featureError(_ message:String)->FeatureError { FeatureError(code:"sdk_error",message:message,details:nil) }
func doubles(_ values:[Double])->FlutterStandardTypedData { values.withUnsafeBytes { FlutterStandardTypedData(float64:Data($0)) } }
final class MapAssets {
    private let registrar:FlutterPluginRegistrar
    init(registrar:FlutterPluginRegistrar) { self.registrar=registrar }
    func assetPath(_ asset:String)throws->String {
        let key=registrar.lookupKey(forAsset:asset)
        guard let path=Bundle.main.path(forResource:key,ofType:nil) else { throw featureError("Asset unavailable: \(asset)") }
        return path
    }
}
