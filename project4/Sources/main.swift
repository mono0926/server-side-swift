import CouchDB
import Cryptor
import Foundation
import HeliumLogger
import Kitura
import KituraNet
import KituraSession
import KituraStencil
import LoggerAPI
import SwiftyJSON

func send(error: String, code: HTTPStatusCode, to response: RouterResponse) {
    _ = try? response.status(code).send(error).end()
}

func context(for request: RouterRequest) -> [String: Any] {
    var result = [String: String]()
    result["username"] = request.session?["username"].string

    return result
}

func password(from str: String, salt: String) -> String {
    let key = PBKDF.deriveKey(fromPassword: str, salt: salt, prf: .sha512, rounds: 250_000, derivedKeyLength: 64)
    return CryptoUtils.hexString(from: key)
}

extension String {
    func removingHTMLEncoding() -> String {
        let result = self.replacingOccurrences(of: "+", with: " ")
        return result.removingPercentEncoding ?? result
    }
}

func getPost(for request: RouterRequest, fields: [String]) -> [String: String]? {
    guard let values = request.body else { return nil }
    guard case .urlEncoded(let body) = values else { return nil }

    var result = [String: String]()

    for field in fields {
        if let value = body[field]?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if value.characters.count > 0 {
                result[field] = value.removingHTMLEncoding()
                continue
            }
        }
        
        return nil
    }
    
    return result
}



HeliumLogger.use()

let connectionProperties = ConnectionProperties(host: "localhost", port: 5984, secured: false)
let client = CouchDBClient(connectionProperties: connectionProperties)
let database = client.database("forum")

let router = Router()

router.setDefault(templateEngine: CustomStencilTemplateEngine())
router.post("/", middleware: BodyParser())
router.all("/static", middleware: StaticFileServer())

router.all(middleware: Session(secret: "The rain in Spain falls mainly on the Spaniards"))

router.get("/") {
    request, response, next in

    database.queryByView("forums", ofDesign: "forum", usingParameters: []) { forums, error in
        defer { next() }

        if let error = error {
            send(error: error.localizedDescription, code: .internalServerError, to: response)
        } else if let forums = forums {
            var forumContext = context(for: request)
            forumContext["forums"] = forums["rows"].arrayObject

            _ = try? response.render("home", context: forumContext)
        }
    }
}

router.get("/forum/:forumid") {
    request, response, next in

    guard let forumID = request.parameters["forumid"] else {
        send(error: "Missing forum ID", code: .badRequest, to: response)
        return
    }

    database.retrieve(forumID) { forum, error in
        if let error = error {
            send(error: error.localizedDescription, code: .notFound, to: response)
        } else if let forum = forum {
            database.queryByView("forum_posts", ofDesign: "forum", usingParameters: [.keys([forumID as Database.KeyType]), .descending(true)]) { messages, error in
                defer { next() }

                if let error = error {
                    send(error: error.localizedDescription, code: .internalServerError, to: response)
                } else if let messages = messages {
                    var pageContext = context(for: request)
                    pageContext["forum_id"] = forum["_id"].stringValue
                    pageContext["forum_name"] = forum["name"].stringValue
                    pageContext["messages"] = messages["rows"].arrayObject

                    _ = try? response.render("forum", context: pageContext)
                }
            }
        }
    }
}

router.get("/forum/:forumid/:messageid") {
    request, response, next in

    guard let forumID = request.parameters["forumid"],
        let messageID = request.parameters["messageid"] else {
            try response.status(.badRequest).end()
            return
    }

    database.retrieve(forumID) { forum, error in
        if let error = error {
            send(error: error.localizedDescription, code: .notFound, to: response)
        } else if let forum = forum {
            database.retrieve(messageID) { message, error in
                if let error = error {
                    send(error: error.localizedDescription, code: .notFound, to: response)
                } else if let message = message {
                    database.queryByView("forum_replies", ofDesign: "forum", usingParameters: [.keys([messageID as Database.KeyType])]) { replies, error in
                        defer { next() }

                        if let error = error {
                            send(error: error.localizedDescription, code: .internalServerError, to: response)
                        } else if let replies = replies {
                            var pageContext = context(for: request)
                            pageContext["forum_id"] = forum["_id"].stringValue
                            pageContext["forum_name"] = forum["name"].stringValue
                            pageContext["message"] = message.dictionaryObject!
                            pageContext["replies"] = replies["rows"].arrayObject
                            
                            _ = try? response.render("message", context: pageContext)
                        }
                    }
                }
            }
        }
    }
}

router.get("/users/login") {
    request, response, next in
    defer { next() }

    try response.render("users-login", context: [:])
}

router.post("/users/login") {
    request, response, next in

    if let fields = getPost(for: request, fields: ["username", "password"]) {
        database.retrieve(fields["username"]!) { doc, error in
            defer { next() }

            if let error = error {
                send(error: "Unable to load user.", code: .badRequest, to: response)
            } else if let doc = doc {
                let savedSalt = doc["salt"].stringValue
                let savedPassword = doc["password"].stringValue
                let testPassword = password(from: fields["password"]!, salt: savedSalt)

                if testPassword == savedPassword {
                    request.session?["username"].string = doc["_id"].string
                    _ = try? response.redirect("/")
                } else {
                    print("No match")
                }
            }
        }
    } else {
        send(error: "Missing required fields", code: .badRequest, to: response)
    }
}

router.get("/users/create") {
    request, response, next in
    defer { next() }

    try response.render("users-create", context: [:] )
}

router.post("/users/create") {
    request, response, next in
    defer { next() }

    guard let fields = getPost(for: request, fields: ["username", "password"]) else {
        send(error: "Missing required fields", code: .badRequest, to: response)
        return
    }

    database.retrieve(fields["username"]!) { doc, error in
        if let error = error {
            // username doesn't exist!
            var newUser = [String: String]()
            newUser["_id"] = fields["username"]!
            newUser["type"] = "user"

            let saltString: String

            if let salt = try? Random.generate(byteCount: 64) {
                saltString = CryptoUtils.hexString(from: salt)
            } else {
                saltString = (fields["username"]! + fields["password"]! + "project4").digest(using: .sha512)
            }

            newUser["salt"] = saltString
            newUser["password"] = password(from: fields["password"]!, salt: saltString)

            let newUserJSON = JSON(newUser)

            database.create(newUserJSON) { id, revision, doc, error in
                defer { next() }

                if let doc = doc {
                    response.send("OK!")
                } else {
                    // error
                    send(error: "User could not be created", code: .internalServerError, to: response)
                }
            }
        } else {
            // username exists already!
            send(error: "User already exists", code: .badRequest, to: response)
        }
    }
}

router.post("/forum/:forumid/:messageid?") {
    request, response, next in

    guard let forumID = request.parameters["forumid"] else {
        try response.status(.badRequest).end()
        return
    }

    guard let username = request.session?["username"].string else {
        send(error: "You are not logged in", code: .forbidden, to: response)
        return
    }

    guard let fields = getPost(for: request, fields: ["title", "body"]) else {
        send(error: "Missing required fields", code: .badRequest, to: response)
        return
    }

    var newMessage = [String: String]()
    newMessage["body"] = fields["body"]!

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    newMessage["date"] = formatter.string(from: Date())

    newMessage["forum"] = forumID

    if let messageID = request.parameters["messageid"] {
        newMessage["parent"] = messageID
    } else {
        newMessage["parent"] = ""
    }

    newMessage["title"] = fields["title"]!
    newMessage["type"] = "message"
    newMessage["user"] = username

    let newMessageJSON = JSON(newMessage)

    database.create(newMessageJSON) { id, revision, doc, error in
        defer { next() }

        if let error = error {
            send(error: "Message could not be created", code: .internalServerError, to: response)
        } else if let id = id {

            if newMessage["parent"]! == "" {
                _ = try? response.redirect("/forum/\(forumID)/\(id)")
            } else {
                _ = try? response.redirect("/forum/\(forumID)/\(newMessage["parent"]!)")
            }
        }
    }
}


Kitura.addHTTPServer(onPort: 8090, with: router)
Kitura.run()
