// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "StickyX",
  defaultLocalization: "zh-Hans",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "StickyX", targets: ["StickyX"]),
    .library(name: "StickerXCore", targets: ["StickerXCore"])
  ],
  dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.3")
  ],
  targets: [
    .target(
      name: "StickerXCore",
      dependencies: [
        .product(name: "GRDB", package: "GRDB.swift")
      ],
      path: "Sources/StickerXCore"
    ),
    .executableTarget(
      name: "StickyX",
      dependencies: ["StickerXCore"],
      path: "Sources/StickyX"
    ),
    .testTarget(
      name: "StickerXCoreTests",
      dependencies: ["StickerXCore"],
      path: "Tests/StickerXCoreTests"
    ),
    .testTarget(
      name: "StickyXTests",
      dependencies: ["StickyX"],
      path: "Tests/StickyXTests"
    )
  ]
)
