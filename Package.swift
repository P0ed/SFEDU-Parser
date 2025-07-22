// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Xparse",
	platforms: [
		.macOS(.v15)
	],
	dependencies: [
		.package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
	],
    targets: [
        .executableTarget(
            name: "Xparse",
			dependencies: ["SwiftSoup"]
		),
    ]
)
