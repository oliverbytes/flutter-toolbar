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
    targets: [
        .executableTarget(
            name: "Flugger",
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
