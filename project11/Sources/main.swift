import Foundation
import Kitura
import HeliumLogger
import LoggerAPI

HeliumLogger.use()
let router = Router()
router.post("/", middleware: BodyParser())

let backend = BackEnd()
let frontend = FrontEnd()

Kitura.addHTTPServer(onPort: 8089, with: backend.router)
let frontEndServer = Kitura.addHTTPServer(onPort: 8090, with: frontend.router)

frontEndServer.started { [unowned frontend] in
    frontend.loadCategories()
}

Kitura.run()
