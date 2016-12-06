import Kitura
import SwiftyJSON
import XCTest
@testable import project11

class project11Tests: XCTestCase {
    var frontEnd: FrontEnd!

    func createStory() -> [String: String] {
        let title = "Hello, world"
        let strap = "This is a strap"
        let content = "This is some content"
        let category = "Reviews"
        let slug = "hello-world"

        return ["title": title, "strap": strap, "content": content, "category": category, "slug": slug]
    }

    override func setUp() {
        let backend = BackEnd()
        Kitura.addHTTPServer(onPort: 8089, with: backend.router)
        Kitura.start()

        frontEnd = FrontEnd()
        _ = frontEnd.get("/admin/__topsekrit__/reset")
    }

    override func tearDown() {
        Kitura.stop()
    }

    func testNoStories() {
        if let result = frontEnd.get("/stories")?.arrayObject {
            XCTAssertEqual(result.count, 0)
        } else {
            XCTFail("Fetching stories failed")
        }
    }

    func testNonexistentStory() {
        let result = frontEnd.get("/story/fizzbuzz")?.dictionaryObject
        XCTAssertNil(result, "Nonexistent stories should not load")
    }

    func testCreateStory() {
        let story = createStory()
        let createResult = frontEnd.post("/story/create", fields: story)

        XCTAssertNotNil(createResult, "Creating a story failed")

        if let result = frontEnd.get("/stories")?.arrayObject {
            XCTAssertEqual(result.count, 1, "There should be 1 story")
        } else {
            XCTFail("Fetching stories failed")
        }
    }

    func testCreateBadStory() {
        let createResult = frontEnd.post("/story/create", fields: ["title": "Meh"])
        XCTAssertNil(createResult, "Creating an invalid story should fail")
    }
    
    func testUpdateStory() {
        var story = createStory()
        let _ = frontEnd.post("/story/create", fields: story)

        if let result = frontEnd.get("/stories")?.arrayObject?.first as? [String: Any] {
            let id = result["id"]
            story["title"] = "Modified"

            let updateResult = frontEnd.post("/story/\(id)", fields: story)
            XCTAssertNotNil(updateResult, "Updating a story failed")
        } else {
            XCTFail("Fetching stories failed")
        }
    }

    func testUpdateNonexistentStory() {
        let story = createStory()
        let updateResult = frontEnd.post("/story/fizzbuzz", fields: story)
        XCTAssertNotNil(updateResult, "Updating a nonexistent story should not work")
    }

    static var allTests : [(String, (project11Tests) -> () throws -> Void)] {
        return [
            ("testNoStories", testNoStories),
            ("testNonexistentStory", testNonexistentStory),
            ("testCreateStory", testCreateStory),
            ("testCreateBadStory", testCreateBadStory),
            ("testUpdateStory", testUpdateStory),
            ("testUpdateNonexistentStory", testUpdateNonexistentStory),
        ]
    }
}
