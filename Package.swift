// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TextFlash",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "TextFlash",
            targets: ["TextFlash"]
        ),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "TextFlash",
            path: "Sources/TextFlash",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "TextFlashTests",
            dependencies: ["TextFlash"],
            path: "Tests/TextFlashTests"
        ),
    ],
    // tools 6.0 后默认语言模式为 Swift 6；当前 toolchain 在 SendNonSendable
    // 诊断中会崩溃，先显式钉 v5，待编译器修复后再开严格并发。
    swiftLanguageModes: [.v5]
)
