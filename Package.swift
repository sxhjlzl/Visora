// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Visora",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Visora", targets: ["Visora"])
    ],
    targets: [
        .executableTarget(
            name: "Visora",
            path: "Visora",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ImageIO"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .testTarget(
            name: "VisoraTests",
            dependencies: ["Visora"],
            path: "VisoraTests"
        )
    ]
)
