// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "Mustard",
    products: [
      .library(
        name: "Mustard",
        targets: ["Mustard"]),
    ],
    dependencies: [],
    targets: [
      .target(
        name: "Mustard",
        dependencies: []),
      .testTarget(
        name: "MustardTests",
        dependencies: [
          "Mustard",
        ])
    ],
    swiftLanguageVersions: [.v4, .v4_2]
)
