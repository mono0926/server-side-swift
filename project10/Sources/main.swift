import CouchDB
import Credentials
import CredentialsGitHub
import Foundation
import HeliumLogger
import Kitura
import KituraNet
import KituraSession
import KituraStencil
import LoggerAPI
import SwiftyJSON

let connectionProperties = ConnectionProperties(host: "localhost", port: 5984, secured: false)
let client = CouchDBClient(connectionProperties: connectionProperties)
let database = client.database("instantcoder")


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

func send(error: String, code: HTTPStatusCode, to response: RouterResponse) {
    _ = try? response.status(code).send(error).end()
}

func context(for request: RouterRequest) -> [String: Any] {
    var result = [String: Any]()
    result["username"] = request.userProfile?.displayName
    result["languages"] = ["C", "C++", "C#", "Go", "Java", "JavaScript", "Objective-C", "Perl", "PHP", "Python", "Ruby", "Swift"]

    return result
}

func getUserProfile(for request: RouterRequest, with response: RouterResponse) -> JSON? {
    guard let profileID = request.userProfile?.id else {
        _ = try? response.redirect("/").end()
        return nil
    }

    if let _ = request.session?["gitHubProfile"].dictionaryObject {
        return request.session?["gitHubProfile"]
    } else {
        database.retrieve(profileID) { user, error in
            if let _ = error {
                // user wasn't found!
                _ = try? response.redirect("/signup").end()
            } else if let user = user {
                // user was found, so just log them in
                request.session?["gitHubProfile"] = user
            }
        }
        
        return request.session?["gitHubProfile"]
    }
}

HeliumLogger.use()

let router = Router()
router.setDefault(templateEngine: StencilTemplateEngine())
router.all("/static", middleware: StaticFileServer())
router.all(middleware: Session(secret: "He thrusts his fists against the posts and still insists he sees the ghosts"))
router.post("/", middleware: BodyParser())

let credentials = Credentials()
let gitCredentials = CredentialsGitHub(clientId: "58e3ecf7109eaafdfe8d", clientSecret: "ffe7c864c26d04707b68d0425ee377b67fbb8542", callbackUrl: "http://localhost:8090/login/github/callback", userAgent: "server-side-swift")
credentials.register(plugin: gitCredentials)
credentials.options["failureRedirect"] = "/login/github"

router.all("/projects", middleware: credentials)
router.all("/signup", middleware: credentials)

router.get("/login/github", handler: credentials.authenticate(credentialsType: gitCredentials.name))
router.get("/login/github/callback", handler: credentials.authenticate(credentialsType: gitCredentials.name))

router.get("/") {
    request, response, next in
    defer { next() }

    var pageContext = context(for: request)
    pageContext["page_home"] = true

    try response.render("home", context: pageContext)
}

router.get("/signup") {
    request, response, next in
    defer { next() }

    guard let profile = request.userProfile else { return }

    var pageContext = context(for: request)
    try response.render("signup", context: pageContext)
}

router.post("/signup") {
    request, response, next in
    defer { next() }

    guard let profile = request.userProfile else { return }
    guard let fields = getPost(for: request, fields: ["language"]) else { return }

    database.retrieve(profile.id) { user, error in
        if let error = error {
            // user wasn't found!

            let gitHubURL = URL(string: "http://api.github.com/user/\(profile.id)")!
            guard var gitHubProfile = try? Data(contentsOf: gitHubURL) else { return }

            var gitHubJSON = JSON(data: gitHubProfile)
            gitHubJSON["_id"].stringValue = gitHubJSON["id"].stringValue
            _ = gitHubJSON.dictionaryObject?.removeValue(forKey: "id")
            gitHubJSON["type"].stringValue = "coder"
            gitHubJSON["language"].stringValue = fields["language"]!

            database.create(gitHubJSON) { id, rev, doc, error in
                if let doc = doc {
                    request.session?["gitHubProfile"] = gitHubJSON
                }
            }
        } else if let user = user {
            // user was found, so just log them in
            request.session?["gitHubProfile"] = user
        }
    }
    
    _ = try? response.redirect("/projects/mine").end()
}

router.get("/projects/mine") {
    request, response, next in
    defer { next() }

    guard let profile = getUserProfile(for: request, with: response) else { return }
    guard let gitHubID = profile["login"].string else { return }

    var pageContext = context(for: request)

    database.queryByView("projects_by_owner", ofDesign: "instantcoder", usingParameters: [.keys([gitHubID as Database.KeyType])]) { projects, error in
        if let error = error {
            send(error: error.localizedDescription, code: .internalServerError, to: response)
        } else if let projects = projects {
            pageContext["projects"] = projects["rows"].arrayObject
        }
    }

    pageContext["page_projects_mine"] = true
    try response.render("projects_mine", context: pageContext)
}

router.get("/projects/delete/:id/:rev") {
    request, response, next in
    defer { next() }

    guard let profile = getUserProfile(for: request, with: response) else { return }

    guard let id = request.parameters["id"] else { return }
    guard let rev = request.parameters["rev"] else { return }

    database.delete(id, rev: rev) { error in
        _ = try? response.redirect("/projects/mine")
    }
}

router.get("/projects/all") {
    request, response, next in
    defer { next() }

    guard let profile = getUserProfile(for: request, with: response) else { return }

    var pageContext = context(for: request)

    database.queryByView("projects", ofDesign: "instantcoder", usingParameters: []) { projects, error in
        if let error = error {
            send(error: error.localizedDescription, code: .internalServerError, to: response)
        } else if let projects = projects {
            pageContext["projects"] = projects["rows"].arrayObject
        }
    }

    pageContext["page_projects_all"] = true
    try response.render("projects_all", context: pageContext)
}

router.get("/projects/new") {
    request, response, next in
    defer { next() }

    guard let profile = getUserProfile(for: request, with: response) else { return }

    var pageContext = context(for: request)
    pageContext["page_projects_new"] = true

    try response.render("projects_new", context: pageContext)
}

router.post("/projects/new") {
    request, response, next in

    guard let profile = getUserProfile(for: request, with: response) else { return }

    guard let fields = getPost(for: request, fields: ["name", "description", "language"]) else {
        send(error: "Missing required fields", code: .badRequest, to: response)
        return
    }

    var newProject = fields
    newProject["type"] = "project"
    newProject["owner"] = profile["login"].stringValue
    let newDocument = JSON(newProject)

    database.create(newDocument) {  id, revision, doc, error in
        if let error = error {
            send(error: error.localizedDescription, code: .internalServerError, to: response)
            return
        }
        
        _ = try? response.redirect("/projects/mine")
        next()
    }
}

router.get("/projects/search") {
    request, response, next in
    defer { next() }

    guard let profile = getUserProfile(for: request, with: response) else { return }

    var pageContext = context(for: request)

    if let languageParameter = request.queryParameters["language"] {
        database.queryByView("projects_by_language", ofDesign: "instantcoder", usingParameters: [.keys([languageParameter as Database.KeyType])]) { projects, error in
            if let error = error {
                send(error: error.localizedDescription, code: .internalServerError, to: response)
            } else if let projects = projects {
                pageContext["projects"] = projects["rows"].arrayObject
            }
        }

        database.queryByView("coders_by_language", ofDesign: "instantcoder", usingParameters: [.keys([languageParameter as Database.KeyType])]) { projects, error in
            if let error = error {
                send(error: error.localizedDescription, code: .internalServerError, to: response)
            } else if let projects = projects {
                pageContext["coders"] = projects["rows"].arrayObject
            }
        }
    }
    
    pageContext["page_projects_search"] = true
    try response.render("projects_search", context: pageContext)
}


Kitura.addHTTPServer(onPort: 8090, with: router)
Kitura.run()
