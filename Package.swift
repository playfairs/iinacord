// swift-tools-version:5.7
import PackageDescription

let package = Package(
  name: "IINAcord",
  platforms: [.macOS(.v12)],
  products: [
    .executable(name: "IINAcord", targets: ["IINAcord"])
  ],
  targets: [
    .executableTarget(
      name: "IINAcord",
      path: "Sources/IINAcord",
      resources: [.process("Resources")]
    ),
    .testTarget(
      name: "IINAcordTests",
      dependencies: ["IINAcord"],
      path: "Tests/IINAcordTests"
    ),
  ]
)
