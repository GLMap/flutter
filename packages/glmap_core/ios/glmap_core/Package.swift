// swift-tools-version:5.9
import PackageDescription
import Foundation
let native: Package.Dependency = ProcessInfo.processInfo.environment["GLMAP_SDK_DIR"].map {
    .package(name: "GLMapSwift", path: "\($0)/ios")
} ?? .package(url: "https://github.com/GLMap/GLMapSwift.git", exact: "2.2.0")
let package = Package(name: "glmap_core", platforms: [.iOS("16.4")],
    products: [.library(name: "glmap-core", targets: ["glmap_core"])],
    dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework"), native],
    targets: [
        .target(name: "glmap_core", dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework"), .product(name: "GLMapCore", package: "GLMapSwift")])
    ])
