import Foundation
import HeliumLogger
import Kitura
import KituraStencil
import LoggerAPI
import SwiftGD

HeliumLogger.use()

let router = Router()

router.setDefault(templateEngine: StencilTemplateEngine())
router.post("/", middleware: BodyParser())
router.all("/static", middleware: StaticFileServer())

let rootDirectory = URL(fileURLWithPath: "\(FileManager().currentDirectoryPath)/public/uploads")
let originalsDirectory = rootDirectory.appendingPathComponent("originals")
let thumbsDirectory = rootDirectory.appendingPathComponent("thumbs")

router.get("/") {
    request, response, next in
    defer { next() }

    let fm = FileManager()
    guard let files = try? fm.contentsOfDirectory(at: originalsDirectory, includingPropertiesForKeys: nil) else { return }
    let allFilenames = files.map { $0.lastPathComponent }
    let visibleFilenames = allFilenames.filter { !$0.hasPrefix(".") }

    try response.render("home", context: ["files": visibleFilenames])
}

router.post("/upload") {
    request, response, next in
    defer { next() }

    guard let values = request.body else { return }
    guard case .multipart(let parts) = values else { return }

    let acceptableTypes = ["image/png", "image/jpeg"]

    for part in parts {
        guard acceptableTypes.contains(part.type) else { continue }
        guard case .raw(let data) = part.body else { continue }

        let cleanedFilename = part.filename.replacingOccurrences(of: " ", with: "-")
        let newURL = originalsDirectory.appendingPathComponent(cleanedFilename)

        _ = try? data.write(to: newURL)

        let thumbURL = thumbsDirectory.appendingPathComponent(cleanedFilename)

        if let image = Image(url: newURL) {
            if let resized = image.resizedTo(width: 300) {
                resized.write(to: thumbURL)
            }
        }
    }
    
    try response.redirect("/")
}

Kitura.addHTTPServer(onPort: 8090, with: router)
Kitura.run()
