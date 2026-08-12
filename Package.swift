// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Flunner",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .executable(
            name: "Flunner",
            targets: ["Flunner"]
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
            name: "Flunner",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ],
            path: "Sources/Flunner",
            exclude: [
                "Info.plist",
                "Flunner.entitlements",
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
            name: "FlunnerTests",
            dependencies: ["Flunner"],
            path: "Tests/FlunnerTests"
        ),
    ]
)
