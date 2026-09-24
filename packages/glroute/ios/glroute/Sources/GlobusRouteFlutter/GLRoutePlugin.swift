import Flutter
public final class GLRoutePluginImplementation: NSObject, FlutterPlugin {
    private let service:ServiceBridge
    private init(registrar:FlutterPluginRegistrar) { service=ServiceBridge(messenger:registrar.messenger()); super.init() }
    public static func register(with registrar:FlutterPluginRegistrar) { registrar.publish(GLRoutePluginImplementation(registrar:registrar)) }
    public func detachFromEngine(for registrar:FlutterPluginRegistrar) { service.detach(); }
}

@_cdecl("GlobusFlutterRouteRegister")
public func registerRoutePlugin(_ pointer: UnsafeMutableRawPointer) {
    let registrar=Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as! FlutterPluginRegistrar
    GLRoutePluginImplementation.register(with:registrar)
}
