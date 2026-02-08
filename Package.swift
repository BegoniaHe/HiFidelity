// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HiFidelity",
    platforms: [.macOS(.v13)],
    products: [],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.8.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.8.1")
    ],
    targets: [
        .target(
            name: "HiFidelity",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                "Sparkle"
            ],
            path: "./HiFidelity"
        )
    ]
)
