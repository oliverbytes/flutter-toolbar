// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FlutterToolbar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "FlutterToolbar",
            targets: ["FlutterToolbar"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "FlutterToolbar",
            path: "Sources/FlutterToolbar",
            exclude: [
                "Info.plist",
                "FlutterToolbar.entitlements"
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
            ]
        ),
    ]
)