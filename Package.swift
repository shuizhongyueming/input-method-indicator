// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "input-method-indicator",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "input-method-indicator", targets: ["InputMethodIndicator"])
    ],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.6.0")
    ],
    targets: [
        .executableTarget(
            name: "InputMethodIndicator",
            dependencies: ["TOMLKit"],
            path: "Sources"
        )
    ]
)
