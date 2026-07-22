// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FeedbackSDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(name: "FeedbackSDK", targets: ["FeedbackSDK"]),
    ],
    targets: [
        .target(name: "FeedbackSDK"),
        .testTarget(
            name: "FeedbackSDKTests",
            dependencies: ["FeedbackSDK"]
        ),
    ]
)
