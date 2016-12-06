import Cryptor
import Foundation
import HeliumLogger
import Kitura
import KituraNet
import LoggerAPI
import MySQL
import SwiftyJSON

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
let router = Router()
router.post("/", middleware: BodyParser())

router.get("/:user/posts") {
    request, response, next in
    defer { next() }

    guard let user = request.parameters["user"] else { return }

    let (db, connection) = try connectToDatabase()

    let query = "SELECT `id`, `user`, `message`, `date` FROM `posts` WHERE `user` = ? ORDER BY `date` DESC;"
    let posts = try connection.execute(query, [user])

    var parsedPosts = [[String: Any]]()

    for post in posts {
        var postDictionary = [String: Any]()
        postDictionary["id"] = post["id"]?.int
        postDictionary["user"] = post["user"]?.string
        postDictionary["message"] = post["message"]?.string
        postDictionary["date"] = post["date"]?.string
        parsedPosts.append(postDictionary)
    }

    var result = [String: Any]()
    result["status"] = "ok"
    result["posts"] = parsedPosts

    let json = JSON(result)

    do {
        try response.status(.OK).send(json: json).end()
    } catch {
        Log.warning("Failed to send /:user/posts for \(user): \(error.localizedDescription)")
    }
}

router.post("/login") {
    request, response, next in
    defer { next() }

    guard let fields = getPost(for: request, fields: ["username", "password"]) else {
        _ = try? response.status(.badRequest).send("Missing required fields").end()
        return
    }

    let (db, connection) = try connectToDatabase()

    let query = "SELECT `password`, `salt` FROM `users` WHERE `id` = ?;"
    let users = try connection.execute(query, [fields["username"]!])
    guard let user = users.first else { return }

    guard let savedPassword = user["password"]?.string else { return }
    guard let savedSalt = user["salt"]?.string else { return }

    let testPassword = password(from: fields["password"]!, salt: savedSalt)

    if savedPassword == testPassword {
        try connection.execute("DELETE FROM `tokens` WHERE `expiry` < NOW()", [])

        let token = UUID().uuidString
        try connection.execute("INSERT INTO `tokens` VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 1 DAY));", [token, fields["username"]!])

        var result = [String: Any]()
        result["status"] = "ok"
        result["token"] = token

        let json = JSON(result)

        do {
            try response.status(.OK).send(json: json).end()
        } catch {
            Log.warning("Failed to send /login for \(user): \(error.localizedDescription)")
        }
    }
}

router.post("/post/:reply?") {
    request, response, next in
    defer { next() }

    guard let fields = getPost(for: request, fields: ["token", "message"]) else {
        _ = try? response.status(.badRequest).send("Missing required fields").end()
        return
    }

    let replyTo: String

    if let reply = request.parameters["reply"] {
        replyTo = reply
    } else {
        replyTo = ""
    }

    let (db, connection) = try connectToDatabase()

    let readQuery = "SELECT `user` FROM `tokens` WHERE `uuid` = ?;"
    let users = try connection.execute(readQuery, [fields["token"]!])
    guard let username = users.first?["user"]?.string else { return }

    let writeQuery = "INSERT INTO `posts` (`user`, `message`, `parent`, `date`) VALUES (?, ?, ?, NOW())"

    try connection.execute(writeQuery, [username, fields["message"]!, Int(replyTo) ?? 0])

    let lastInsertID = try connection.execute("SELECT LAST_INSERT_ID() as `id`;", [])
    guard let insertID = lastInsertID.first?["id"]?.string else { return }

    var result = [String: Any]()
    result["status"] = "ok"
    result["id"] = insertID

    let json = JSON(result)

    do {
        try response.status(.OK).send(json: json).end()
    } catch {
        Log.warning("Failed to send /post for \(username): \(error.localizedDescription)")
    }
}

Kitura.addHTTPServer(onPort: 8090, with: router)
Kitura.run()
