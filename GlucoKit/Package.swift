// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GlucoKit",
    // macOS n'est pas une cible du produit : c'est ce qui permet de lancer
    // `swift test` directement sur la machine, sans passer par un simulateur.
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "GlucoKit", targets: ["GlucoKit"])
    ],
    targets: [
        .target(name: "GlucoKit"),
        .testTarget(name: "GlucoKitTests", dependencies: ["GlucoKit"])
    ]
)
