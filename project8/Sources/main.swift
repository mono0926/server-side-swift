import Foundation
import HeliumLogger
import Kitura
import KituraStencil
import LoggerAPI
import SwiftGD

func image(from request: RouterRequest) -> Image? {
    guard let imageFilename = request.queryParameters["url"] else { return nil }
    guard let imageFilenameDecoded = imageFilename.removingPercentEncoding else { return nil }
    guard let url = URL(string: imageFilenameDecoded) else { return nil}

    if let imageData = try? Data(contentsOf: url) {
        let temporaryName = NSTemporaryDirectory().appending("input.png")
        let temporaryURL = URL(fileURLWithPath: temporaryName)
        _ = try? imageData.write(to: temporaryURL)

        if let image = Image(url: temporaryURL) {
            return image
        }
    }
    
    return nil
}

HeliumLogger.use()
let router = Router()
router.setDefault(templateEngine: StencilTemplateEngine())

router.get("/") {
    request, response, next in
    defer { next() }

    try response.render("home", context: [:])
}

router.get("/fetch") {
    request, response,  next in
    defer { next() }

    let asciiBlocks = ["@", "#", "*", "+", ";", ":", ",", ".", "`", " "]
    let blockSize = 2

    guard let image = image(from: request) else { return }

    let imageSize = image.size

    var rows = [[String]]()
    rows.reserveCapacity(imageSize.height)

    for y in stride(from: 0, to: imageSize.height, by: blockSize) {
        var row = [String]()
        row.reserveCapacity(imageSize.width)

        for x in stride(from: 0, to: imageSize.width, by: blockSize) {
            let color = image.get(pixel: Point(x: x, y: y))
            let brightness = color.redComponent + color.greenComponent + color.blueComponent
            let sum = Int(round(brightness * 3))

            row.append(asciiBlocks[sum])
        }

        rows.append(row)
    }
    
    
    let output = rows.reduce("") {
        $0 + $1.joined(separator: " ") + "\n"
    }
    
    try response.send(output).end()
}


Kitura.addHTTPServer(onPort: 8090, with: router)
Kitura.run()
