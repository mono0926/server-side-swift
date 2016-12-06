//
//  FrontEnd.swift
//  project11
//
//  Created by Paul Hudson on 05/12/2016.
//
//

import Foundation
import Kitura
import KituraNet
import KituraStencil
import Markdown
import Stencil
import SwiftyJSON
import SwiftSlug

class FrontEnd {
    var backEndSchema = "http"
    var backEndHost = "localhost"
    var backEndPort: Int16 = 8089

    var categories = [String]()

    lazy var router: Router = {
        let router = Router()
        router.setDefault(templateEngine: self.createTemplateEngine())
        router.post("/", middleware: BodyParser())

        router.all("/static", middleware: StaticFileServer())
        router.all("/static/*") { req, res, next in try res.end() }

        router.get("/", handler: self.getHomePage)
        router.get("/:category/:id/:slug", handler: self.getStory)

        let adminRouter = Router()
        adminRouter.get("/", handler: self.getAdminHome)
        adminRouter.get("/edit/:id?", handler: self.getAdminEdit)
        adminRouter.post("/edit/:id?", handler: self.postAdminEdit)
        router.all("/admin", middleware: adminRouter)

        return router
    }()

    func createTemplateEngine() -> StencilTemplateEngine {
        let namespace = Namespace()

        namespace.registerFilter("markdown") { (value: Any?) in
            guard let unwrapped = value as? String else { return value }
            let trimmed = unwrapped.replacingOccurrences(of: "\r\n", with: "\n")

            if let md = try? Markdown(string: trimmed) {
                if let doc = try? md.document() {
                    return doc
                }
            }

            return unwrapped
        }

        namespace.registerFilter("link") { (value: Any?) in
            guard let unwrapped = value as? [String: Any] else { return value }

            // ensure all three fields are present
            guard let category = unwrapped["category"] as? String else { return value }
            guard let id = unwrapped["id"] else { return value }
            guard let slug = unwrapped["slug"] else { return value }

            return "/\(category.lowercased())/\(id)/\(slug)"
        }

        return StencilTemplateEngine(namespace: namespace)
    }

    func get(_ path: String) -> JSON? {
        return fetch(path, method: "GET", body: "")
    }

    func post(_ path: String, fields: [String: Any]) -> JSON? {
        let string = JSON(fields).rawString() ?? ""
        return fetch(path, method: "POST", body: string)
    }

    func fetch(_ path: String, method: String, body: String) -> JSON? {
        var requestOptions: [ClientRequest.Options] = []

        requestOptions.append(.schema("\(backEndSchema)://"))
        requestOptions.append(.hostname(backEndHost))
        requestOptions.append(.port(backEndPort))
        requestOptions.append(.method(method))
        requestOptions.append(.path(path))

        let headers = ["Content-Type": "application/json"]
        requestOptions.append(.headers(headers))

        var responseBody = Data()

        let req = HTTP.request(requestOptions) { response in
            if let response = response {
                guard response.statusCode == .OK else { return }
                _ = try? response.readAllData(into: &responseBody)
            }
        }

        req.end(body)

        if responseBody.count > 0 {
            return JSON(data: responseBody)
        } else {
            return nil
        }
    }

    func context(for request: RouterRequest) -> [String: Any] {
        var result = [String: Any]()
        result["categories"] = categories
        return result
    }

    func renderError(_ message: String, _ request: RouterRequest, _ response: RouterResponse, _ next: () -> Void) throws {
        try response.send("Error: \(message)").end()
    }

    func getHomePage(request: RouterRequest, response: RouterResponse, next: () -> Void) throws {
        defer { next() }
        var pageContext = context(for: request)
        pageContext["title"] = "Top Stories"
        pageContext["stories"] = get("/stories")?.arrayObject
        try response.render("home", context: pageContext)
    }

    func getStory(request: RouterRequest, response: RouterResponse, next: () -> Void) throws {
        guard let id = request.parameters["id"] else {
            try renderError("Missing ID", request, response, next)
            return
        }

        guard let story = get("/story/\(id)")?.dictionaryObject else {
            try renderError("Page not found", request, response, next)
            return
        }

        var pageContext = context(for: request)
        pageContext["title"] = story["title"] ?? ""
        pageContext["story"] = story
        try response.render("read", context: pageContext).end()
    }

    func getAdminHome(request: RouterRequest, response: RouterResponse, next: () -> Void) throws {
        defer { next() }
        var pageContext = context(for: request)
        pageContext["title"] = "Admin"
        pageContext["stories"] = get("/stories")?.arrayObject
        try response.render("admin_home", context: pageContext)
    }

    func getAdminEdit(request: RouterRequest, response: RouterResponse, next: () -> Void) throws {
        defer { next() }

        var pageContext = context(for: request)
        pageContext["title"] = "Edit"

        if let storyID = request.parameters["id"] {
            pageContext["story"] = get("/story/\(storyID)")?.dictionaryObject
        }

        try response.render("admin_edit", context: pageContext)
    }

    func postAdminEdit(request: RouterRequest, response: RouterResponse, next: () -> Void) throws {
        var pageContext = context(for: request)
        pageContext["title"] = "Edit"

        guard let values = request.body else { return }
        guard case .urlEncoded(let rawPost) = values else { return }

        if var fields = request.getPost(fields: ["title", "strap", "content", "category"]) {
            let slug = rawPost["slug"]?.trimmingCharacters(in: .whitespacesAndNewlines)

            if let unwrappedSlug = slug, unwrappedSlug.characters.count > 0 {
                fields["slug"] = unwrappedSlug
            } else {
                fields["slug"] = fields["title"]!
            }

            fields["slug"] = (try? fields["slug"]!.convertedToSlug()) ?? fields["slug"]!

            let postResult: JSON?

            if let storyID = request.parameters["id"] {
                postResult = post("/story/\(storyID)", fields: fields)
            } else {
                postResult = post("/story/create", fields: fields)
            }

            if let _ = postResult {
                try response.redirect("/admin")
                return
            }
        }

        pageContext["story"] = rawPost
        try response.render("admin_edit", context: pageContext).end()
    }

    func loadCategories() {
        if let remoteCategories = get("/categories")?.arrayObject as? [String] {
            categories = remoteCategories
        }
    }
}

