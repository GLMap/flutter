import Flutter
public final class GLSearchPluginImplementation: NSObject, FlutterPlugin {
    private let service:ServiceBridge
    private init(registrar:FlutterPluginRegistrar) { service=ServiceBridge(messenger:registrar.messenger()); super.init() }
    public static func register(with registrar:FlutterPluginRegistrar) { registrar.publish(GLSearchPluginImplementation(registrar:registrar)) }
    public func detachFromEngine(for registrar:FlutterPluginRegistrar) { service.detach(); }
}

@_cdecl("GlobusFlutterSearchRegister")
public func registerSearchPlugin(_ pointer: UnsafeMutableRawPointer) {
    let registrar=Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as! FlutterPluginRegistrar
    GLSearchPluginImplementation.register(with:registrar)
}
