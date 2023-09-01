// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "djvu",
    platforms: [.iOS(.v13), .macOS(.v12)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "djvu",
            targets: ["djvu"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "djvu",
            dependencies: ["libdjvu"]),
        .target(name: "libdjvu",
                dependencies: [],
                cSettings: [
                    .define("HAVE_PTHREAD"),
                    .define("NS_BLOCK_ASSERTIONS", to: "1"),
                    .define("HAVE_CONFIG_H")
                ],
                cxxSettings: [
                    .define("HAVE_PTHREAD"),
                    .define("NS_BLOCK_ASSERTIONS", to: "1"),
                    .define("HAVE_CONFIG_H")
                ],
                linkerSettings: [
                    .linkedFramework("Accelerate")
                ]),
        .testTarget(
            name: "djvu-swiftTests",
            dependencies: ["djvu"]),
    ],
    cxxLanguageStandard: .cxx20
)
