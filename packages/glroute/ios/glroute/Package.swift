// swift-tools-version:5.9
import PackageDescription
import Foundation
let native: Package.Dependency = ProcessInfo.processInfo.environment["GLMAP_SDK_DIR"].map {
    .package(name: "GLMapSwift", path: "\($0)/ios")
} ?? .package(url: "https://github.com/GLMap/GLMapSwift.git", exact: "2.2.0")
let package = Package(name: "glroute", platforms: [.iOS("16.4")],
    products: [.library(name: "glroute", targets: ["glroute"])],
    dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework"), native, .package(name: "glmap_core", path: "../glmap_core")],
    targets: [
        .target(name: "glroute", dependencies: ["GlobusRouteFlutter", .product(name: "FlutterFramework", package: "FlutterFramework")], publicHeadersPath: "include"),
        .target(name: "GlobusRouteFlutter", dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework"), .product(name: "GLRoute", package: "GLMapSwift"), .product(name: "glmap-core", package: "glmap_core")])
    ])
