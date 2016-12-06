//
//  BackEnd.swift
//  project11
//
//  Created by Paul Hudson on 05/12/2016.
//
//

import Foundation
import HeliumLogger
import Kitura
import KituraNet
import LoggerAPI
import MySQL
import SwiftyJSON

class BackEnd {
    lazy var router: Router = {
        let router = Router()

        router.post("/", middleware: BodyParser())

        router.get("/stories", handler: self.getAllStories)
        router.get("/story/:id", handler: self.getStory)
        router.post("/story/:id", handler: self.postStory)

        router.get("/categories", handler: self.getAllCategories)

        return router
    }()

    func connectToDatabase() throws -> (Database, Connection) {
        let mysql = try Database(
            host: "localhost",
            user: "swift",
            password: "swift",
            database: "swift"
        )

        let connection = try mysql.makeConnection()
        return (mysql, connection)
    }

    func getAllStories(request: RouterRequest, response: RouterResponse, next: () -> Void) throws {
        defer { next() }

        let (db, connection) = try connectToDatabase()

        let query = "SELECT p.`id`, `title`, `strap`, c.`name` AS `category`, `slug`, `date` FROM `posts` p, `categories` c WHERE p.`category` = c.`id` ORDER BY `date` DESC;"
        let posts = try db.execute(query, [], connection)

        var parsedPosts = [[String: Any]]()

        for post in posts {
            var postDictionary = [String: Any]()
            postDictionary["id"] = post["id"]?.int
            postDictionary["title"] = post["title"]?.string
            postDictionary["strap"] = post["strap"]?.string
            postDictionary["category"] = post["category"]?.string
            postDictionary["slug"] = post["slug"]?.string
            postDictionary["date"] = post["date"]?.string

            parsedPosts.append(postDictionary)
        }

        response.status(.OK).send(json: JSON(parsedPosts))
    }

    func getStory(request: RouterRequest, response: RouterResponse, next: () -> Void) throws {
        defer { next() }

        guard let storyID = request.parameters["id"] else {
            response.status(.badRequest).send("Missing story ID.")
            return
        }

        let (db, connection) = try connectToDatabase()

        let query = "SELECT p.`id`, `title`, `strap`, `content`, c.`name` AS `category`, `slug`, `date` FROM `posts` p, `categories` c WHERE p.`category` = c.`id` AND p.`id` = ?;"
        let posts = try db.execute(query, [storyID], connection)

        guard let post = posts.first else {
            response.status(.notFound).send("Unknown story ID.")
            return
        }

        var postDictionary = [String: Any]()
        postDictionary["id"] = post["id"]?.int
        postDictionary["title"] = post["title"]?.string
        postDictionary["strap"] = post["strap"]?.string
        postDictionary["content"] = post["content"]?.string
        postDictionary["category"] = post["category"]?.string
        postDictionary["slug"] = post["slug"]?.string
        postDictionary["date"] = post["date"]?.string

        response.status(.OK).send(json: JSON(postDictionary))
    }

    func postStory(request: RouterRequest, response: RouterResponse, next: () -> Void) throws {
        defer { next() }

        guard let storyID = request.parameters["id"] else {
            response.status(.badRequest).send("Missing story ID.")
            return
        }

        guard var fields = request.getPost(fields: ["title", "strap", "content", "category", "slug"]) else {
            response.status(.badRequest).send("Missing required fields.")
            return
        }

        let (db, connection) = try connectToDatabase()
        let categoryQuery = "SELECT `id` FROM `categories` WHERE `name` = ?"

        if let categoryID = db.singleQuery(categoryQuery, [fields["category"]!], connection)?.int {
            fields["category"] = String(categoryID)
        } else {
            response.status(.badRequest).send("Unknown category.")
            return
        }

        let query: String
        var orderedFields = [fields["title"]!, fields["strap"]!, fields["content"]!, fields["category"]!, fields["slug"]!]

        if storyID == "create" {
            query = "INSERT INTO `posts` (`title`, `strap`, `content`, `category`, `slug`, `date`) VALUES (?, ?, ?, ?, ?, NOW());"
        } else {
            query = "UPDATE `posts` SET `title` = ?, `strap` = ?, `content` = ?, `category` = ?, `slug` = ? WHERE `id` = ?;"
            orderedFields.append(storyID)
        }

        do {
            _ = try db.execute(query, orderedFields, connection)

            let result = ["status": "ok"]
            response.status(.OK).send(json: JSON(result))
        } catch {
            response.status(.notFound).send("Unknown story ID.")
            return
        }
    }

    func getAllCategories(request: RouterRequest, response: RouterResponse, next: () -> Void) throws {
        defer { next() }

        let (db, connection) = try connectToDatabase()

        let query = "SELECT `name` FROM `categories` ORDER BY `name`;"
        let posts = try db.execute(query, [], connection)
        let categoryNames = posts.flatMap { $0["name"]?.string }

        response.status(.OK).send(json: JSON(categoryNames))
    }
}

