// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "UniversalTranslatorApp",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "UniversalTranslatorApp",
            targets: ["UniversalTranslatorApp"]
        ),
    ],
    dependencies: [
        // Firebase SDK
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            from: "10.0.0"
        ),
    ],
    targets: [
        .target(
            name: "UniversalTranslatorApp",
            dependencies: [
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "FirebasePerformance", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
            ],
            path: "Source"
        ),
        .testTarget(
            name: "UniversalTranslatorAppTests",
            dependencies: ["UniversalTranslatorApp"],
            path: "Tests"
        ),
    ]
)