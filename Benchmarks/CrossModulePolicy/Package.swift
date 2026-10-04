// swift-tools-version: 6.1
import Foundation
import PackageDescription

let specificationCorePath = ProcessInfo.processInfo.environment["SPECIFICATIONCORE_PACKAGE"] ?? "../.."
let specificationCoreIdentity = URL(fileURLWithPath: specificationCorePath).standardizedFileURL.lastPathComponent

let package = Package(
    name: "CrossModulePolicyBenchmark",
    dependencies: [.package(path: specificationCorePath)],
    targets: [
        .executableTarget(
            name: "CrossModulePolicyBenchmark",
            dependencies: [.product(name: "SpecificationCore", package: specificationCoreIdentity)]
        )
    ]
)
