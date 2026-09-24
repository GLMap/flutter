// swift-tools-version: 5.9
import PackageDescription
import Foundation

let native: Package.Dependency = ProcessInfo.processInfo.environment["GLMAP_SDK_DIR"].map {
    .package(name: "GLMapSwift", path: "\($0)/ios")
} ?? .package(url: "https://github.com/GLMap/GLMapSwift.git", exact: "2.2.0")
let package = Package(name: "glmap_flutter", platforms: [.iOS("16.4")],
    products: [.library(name: "glmap-flutter", targets: ["glmap_flutter"])],
    dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework"), native],
    targets: [
        .target(name: "BulkGeometry", dependencies: [.product(name: "GLMap", package: "GLMapSwift")]),
        .target(name: "glmap_flutter", dependencies: ["BulkGeometry",
            .product(name: "FlutterFramework", package: "FlutterFramework"),
            .product(name: "GLMap", package: "GLMapSwift"),
            .product(name: "GLSearch", package: "GLMapSwift"),
            .product(name: "GLRoute", package: "GLMapSwift")], exclude: ["PrivacyInfo.xcprivacy"])
    ])
