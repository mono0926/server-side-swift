import HeliumLogger
import Kitura

HeliumLogger.use()

let router = Router()
router.setDefault(templateEngine: CustomStencilTemplateEngine())

router.get("/") {
    request, response, next in
    defer { next() }

    let haters = "hating"
    let names = ["Taylor", "Paul", "Justin", "Adele"]
    let hamsters = [String]()
    let quote = "He thrusts his fists against the posts and still insists he sees the ghosts"

    let context: [String: Any] = ["haters": haters, "names": names, "hamsters": hamsters, "quote": quote]
    try response.render("home", context: context)
}

Kitura.addHTTPServer(onPort: 8090, with: router)
Kitura.run()
