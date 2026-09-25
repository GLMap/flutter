import Flutter
import UIKit
import XCTest

/// Tests the plugin that is actually linked into the demo, without a second engine.
final class RunnerTests: XCTestCase {
    func testMapPluginRegistersCurrentPlatformView() throws {
        let plugin = try XCTUnwrap(NSClassFromString("GLMapPlugin") as? FlutterPlugin.Type)
        let registrar = RecordingRegistrar()
        defer { registrar.factory = nil }
        plugin.register(with: registrar)
        XCTAssertEqual(registrar.identifiers, ["software.globus.glmap/view"])
        XCTAssertNotNil(registrar.factory)
    }

    func testMapFactoryUsesStandardCreationCodec() throws {
        let plugin = try XCTUnwrap(NSClassFromString("GLMapPlugin") as? FlutterPlugin.Type)
        let registrar = RecordingRegistrar()
        defer { registrar.factory = nil }
        plugin.register(with: registrar)
        let factory = try XCTUnwrap(registrar.factory)
        let codec = try XCTUnwrap(factory.createArgsCodec?())
        let arguments: NSDictionary = ["camera": ["latitude": 42.4341, "longitude": 19.26, "zoom": 13.0]]
        let decoded = try XCTUnwrap(codec.decode(codec.encode(arguments)) as? NSDictionary)
        XCTAssertEqual(decoded, arguments)
    }
}

private final class RecordingMessenger: NSObject, FlutterBinaryMessenger {
    func send(onChannel channel: String, message: Data?) {}
    func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) { callback?(nil) }
    func setMessageHandlerOnChannel(_ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?) -> FlutterBinaryMessengerConnection { 0 }
    func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}

private final class RecordingRegistrar: NSObject, FlutterPluginRegistrar {
    private let binaryMessenger = RecordingMessenger()
    var identifiers: [String] = []
    var factory: FlutterPlatformViewFactory?
    var viewController: UIViewController? { nil }
    func messenger() -> FlutterBinaryMessenger { binaryMessenger }
    func textures() -> FlutterTextureRegistry { fatalError("Registration does not allocate textures") }
    func publish(_ value: NSObject) {}
    func addMethodCallDelegate(_ delegate: FlutterPlugin, channel: FlutterMethodChannel) {}
    func addApplicationDelegate(_ delegate: FlutterPlugin) {}
    func addSceneDelegate(_ delegate: FlutterSceneLifeCycleDelegate) {}
    func lookupKey(forAsset asset: String) -> String { asset }
    func lookupKey(forAsset asset: String, fromPackage package: String) -> String { "packages/\(package)/\(asset)" }
    func valuePublished(byPlugin pluginKey: String) -> NSObject? { nil }
    func register(_ factory: FlutterPlatformViewFactory, withId factoryId: String) {
        self.factory = factory
        identifiers.append(factoryId)
    }
    func register(_ factory: FlutterPlatformViewFactory, withId factoryId: String,
                  gestureRecognizersBlockingPolicy: FlutterPlatformViewGestureRecognizersBlockingPolicy) {
        register(factory, withId: factoryId)
    }
}
