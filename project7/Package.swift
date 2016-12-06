import PackageDescription

let package = Package(
    name: "project7",
    dependencies: [
        .Package(url: "https://github.com/IBM-Swift/Kitura.git", majorVersion: 1),
        .Package(url: "https://github.com/IBM-Swift/HeliumLogger.git", majorVersion: 1),
        .Package(url: "https://github.com/IBM-Swift/BlueCryptor.git", majorVersion: 0, minor: 8),
        .Package(url: "https://github.com/vapor/mysql.git", majorVersion: 1),
    ]
)
