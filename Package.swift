// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Meganote",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Meganote",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
