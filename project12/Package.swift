import PackageDescription

let package = Package(
    name: "project11",
    dependencies: [
        .Package(url: "https://github.com/IBM-Swift/Kitura.git", majorVersion: 1),
        .Package(url: "https://github.com/IBM-Swift/HeliumLogger.git", majorVersion: 1),
        .Package(url: "https://github.com/IBM-Swift/BlueCryptor.git", majorVersion: 0, minor: 8),
        .Package(url: "https://github.com/IBM-Swift/Kitura-StencilTemplateEngine.git", majorVersion: 1),
        .Package(url: "https://github.com/crossroadlabs/Markdown.git", Version("1.0.0-alpha.2")!),
        .Package(url: "https://github.com/twostraws/SwiftSlug.git", majorVersion: 0, minor: 2),
        .Package(url: "https://github.com/vapor/mysql.git", majorVersion: 1)
    ]
)
