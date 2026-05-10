// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacMouseFixPro",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacMouseFixPro", targets: ["MacMouseFixPro"])
    ],
    targets: [
        .executableTarget(
            name: "MacMouseFixPro",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices")
            ]
        )
    ]
)
