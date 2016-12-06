import Kitura
import HeliumLogger
import LoggerAPI
import KituraStencil

HeliumLogger.use()

let router = Router()
router.setDefault(templateEngine: StencilTemplateEngine())

router.all("/static", middleware: StaticFileServer())

router.get("/") {
	request, response, next in
	defer { next() }
	try response.render("home", context: [:])
}

router.get("/staff/:name") {
	request, response, next in
	defer { next() }

	guard let name = request.parameters["name"] else { return }

	let bios = [
		"kirk": "My name is James Kirk and I love snakes.",
		"picard": "My name is Jean-Luc Picard and I'm mad for cats.",
		"sisko": "My name is Benjamin Sisko and I'm all about the budgies.",
		"janeway": "My name is Kathryn Janeway and I want to hug every hamster.",
		"archer": "My name is Jonathan Archer and beagles are my thing."
	]

	var context = [String: Any]()
	context["people"] = bios.keys.sorted()

	if let bio = bios[name] {
		context["name"] = name
		context["bio"] = bio
	}

	try response.render("staff", context: context)
}

router.get("/contact") {
	request, response, next in
	defer { next() }
	try response.render("contact", context: [:])
}

Kitura.addHTTPServer(onPort: 8090, with: router)
Kitura.run()
