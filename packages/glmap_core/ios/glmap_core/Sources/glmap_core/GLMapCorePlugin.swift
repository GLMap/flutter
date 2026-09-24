import Flutter
public final class GLMapCorePlugin: NSObject, FlutterPlugin {
    private let service:SdkBridge
    private init(registrar:FlutterPluginRegistrar) { service=SdkBridge(registrar:registrar); super.init() }
    public static func register(with registrar:FlutterPluginRegistrar) { registrar.publish(GLMapCorePlugin(registrar:registrar)) }
    public func detachFromEngine(for registrar:FlutterPluginRegistrar) { service.detach(); CoreResources.release(registrar.messenger()) }
}
