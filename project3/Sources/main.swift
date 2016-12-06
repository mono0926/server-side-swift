import HeliumLogger
import Kitura

HeliumLogger.use()
let router = Router()

router.get("/hello", handler: {
	request, response, next in
	defer { next() }
	response.send("Hello")
}, {
	request, response, next in
	defer { next() }
	response.send(", world")
})

router.route("/test")
.get() {
	request, response, next in
	defer { next() }
	response.send("You used GET!")
}.post() {
	request, response, next in
	defer { next() }
	response.send("You used POST!")
}

router.get("/games/:name") {
	request, response, next in
	defer { next() }

	guard let name = request.parameters["name"] else { return }
	response.send("Load the \(name) game")
}

router.post("/employees/add", middleware: BodyParser())

router.post("/employees/add") {
	request, response, next in

	guard let values = request.body else {
		try response.status(.badRequest).end()
		return
	}

	guard case .urlEncoded(let body) = values else {
		try response.status(.badRequest).end()
		return
	}

	guard let name = body["name"] else { return }

	response.send("Adding new employee named \(name)")
	next()
}

router.get("/platforms") {
	request, response, next in

	guard let name = request.queryParameters["name"] else {
		try response.status(.badRequest).end()
		return
	}

	response.send("Loading the \(name) platform")
	next()
}

router.post("/messages/create", middleware: BodyParser())

router.post("/messages/create") {
	request, response, next in

	guard let values = request.body else {
		try response.status(.badRequest).end()
		return
	}

	guard case .json(let body) = values else {
		try response.status(.badRequest).end()
		return
	}

	if let title = body["title"].string {
		response.send("Adding new message with the title \(title)")
	} else {
		response.send("You need to provide a title.")
	}

	next()
}

router.get("/search/([0-9]+)/([A-Za-z]+)") {
	request, response, next in
	defer { next() }

	guard let year = request.parameters["0"] else { return }
	guard let string = request.parameters["1"] else { return }

	response.send("You searched for \(string) in \(year)")
}

Kitura.addHTTPServer(onPort: 8090, with: router)
Kitura.run()
