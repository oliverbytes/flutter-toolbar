// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Flugger",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .executable(
            name: "Flugger",
            targets: ["Flugger"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/migueldeicaza/SwiftTerm.git",
            exact: "1.11.2"
        ),
    ],
    targets: [
        .executableTarget(
            name: "Flugger",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ],
            path: "Sources/Flugger",
            exclude: [
                "Info.plist",
                "Flugger.entitlements",
                "Assets.xcassets",
                "Design/AppIconMaster.png"
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
            ]
        ),
        .testTarget(
            name: "FluggerTests",
            dependencies: ["Flugger"],
            path: "Tests/FluggerTests"
        ),
    ]
)
