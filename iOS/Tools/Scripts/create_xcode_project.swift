#!/usr/bin/env swift

import Foundation

// Create Xcode project structure
let projectName = "UniversalTranslator"
let bundleId = "com.universaltranslator.app"
let organizationName = "Universal Translator"
let deploymentTarget = "15.0"

// Project.pbxproj template (simplified)
let pbxprojContent = """
// !$*UTF8*$!
{
    archiveVersion = 1;
    classes = {
    };
    objectVersion = 56;
    objects = {
        /* Begin PBXBuildFile section */
        1D3623260E831E9300F32A8F /* AppDelegate.swift in Sources */ = {isa = PBXBuildFile; fileRef = 1D3623250E831E9300F32A8F /* AppDelegate.swift */; };
        1D3623280E831E9300F32A8F /* SceneDelegate.swift in Sources */ = {isa = PBXBuildFile; fileRef = 1D3623270E831E9300F32A8F /* SceneDelegate.swift */; };
        1D3623290E831E9300F32A8F /* ContentView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 1D3623290E831E9300F32A8F /* ContentView.swift */; };
        1D3623300E831E9300F32A8F /* TranslationService.swift in Sources */ = {isa = PBXBuildFile; fileRef = 1D3623300E831E9300F32A8F /* TranslationService.swift */; };
        1D3623310E831E9300F32A8F /* NetworkConfig.swift in Sources */ = {isa = PBXBuildFile; fileRef = 1D3623310E831E9300F32A8F /* NetworkConfig.swift */; };
        1D3623320E831E9300F32A8F /* GoogleService-Info.plist in Resources */ = {isa = PBXBuildFile; fileRef = 1D3623320E831E9300F32A8F /* GoogleService-Info.plist */; };
        /* End PBXBuildFile section */

        /* Begin PBXFileReference section */
        1D3623240E831E9300F32A8F /* UniversalTranslator.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = UniversalTranslator.app; sourceTree = BUILT_PRODUCTS_DIR; };
        1D3623250E831E9300F32A8F /* AppDelegate.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppDelegate.swift; sourceTree = "<group>"; };
        1D3623270E831E9300F32A8F /* SceneDelegate.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SceneDelegate.swift; sourceTree = "<group>"; };
        1D3623290E831E9300F32A8F /* ContentView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ContentView.swift; sourceTree = "<group>"; };
        1D3623300E831E9300F32A8F /* TranslationService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TranslationService.swift; sourceTree = "<group>"; };
        1D3623310E831E9300F32A8F /* NetworkConfig.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NetworkConfig.swift; sourceTree = "<group>"; };
        1D3623320E831E9300F32A8F /* GoogleService-Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "GoogleService-Info.plist"; sourceTree = "<group>"; };
        1D3623330E831E9300F32A8F /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
        /* End PBXFileReference section */

        /* Begin PBXGroup section */
        1D3623231E831E9300F32A8F = {
            isa = PBXGroup;
            children = (
                1D3623241E831E9300F32A8F /* UniversalTranslator */,
                1D3623251E831E9300F32A8F /* Products */,
            );
            sourceTree = "<group>";
        };
        1D3623241E831E9300F32A8F /* UniversalTranslator */ = {
            isa = PBXGroup;
            children = (
                1D3623250E831E9300F32A8F /* AppDelegate.swift */,
                1D3623270E831E9300F32A8F /* SceneDelegate.swift */,
                1D3623290E831E9300F32A8F /* ContentView.swift */,
                1D3623300E831E9300F32A8F /* TranslationService.swift */,
                1D3623310E831E9300F32A8F /* NetworkConfig.swift */,
                1D3623320E831E9300F32A8F /* GoogleService-Info.plist */,
                1D3623330E831E9300F32A8F /* Info.plist */,
            );
            path = UniversalTranslator;
            sourceTree = "<group>";
        };
        /* End PBXGroup section */
    };
    rootObject = 1D3623231E831E9300F32A8F /* Project object */;
}
"""

// Info.plist content
let infoPlistContent = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>\(bundleId)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <true/>
        <key>UISceneConfigurations</key>
        <dict>
            <key>UIWindowSceneSessionRoleApplication</key>
            <array>
                <dict>
                    <key>UISceneConfigurationName</key>
                    <string>Default Configuration</string>
                    <key>UISceneDelegateClassName</key>
                    <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
                </dict>
            </array>
        </dict>
    </dict>
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>armv7</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
    </dict>
</dict>
</plist>
"""

// Package.swift for SPM
let packageContent = """
// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "UniversalTranslator",
    platforms: [
        .iOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0")
    ],
    targets: [
        .target(
            name: "UniversalTranslator",
            dependencies: [
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk")
            ]
        )
    ]
)
"""

// Create project directory structure
let projectDir = "/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/UniversalTranslator.xcodeproj"
let fileManager = FileManager.default

do {
    // Create directories
    try fileManager.createDirectory(atPath: projectDir, withIntermediateDirectories: true, attributes: nil)
    try fileManager.createDirectory(atPath: projectDir + "/project.xcworkspace", withIntermediateDirectories: true, attributes: nil)
    
    // Write project files
    try pbxprojContent.write(toFile: projectDir + "/project.pbxproj", atomically: true, encoding: .utf8)
    
    // Write Info.plist
    try infoPlistContent.write(toFile: "/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/Info.plist", atomically: true, encoding: .utf8)
    
    // Write Package.swift
    try packageContent.write(toFile: "/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/Package.swift", atomically: true, encoding: .utf8)
    
    print("✅ Xcode project structure created successfully!")
    print("📁 Project location: \(projectDir)")
    print("\nNext steps:")
    print("1. Open Xcode")
    print("2. File → Open → Navigate to: /Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/")
    print("3. Open UniversalTranslator.xcodeproj")
    print("4. Add Firebase SDK via Swift Package Manager")
    print("5. Build and run!")
    
} catch {
    print("❌ Error creating project: \(error)")
}