import Kitura
import SwiftyJSON
import XCTest
@testable import project11

class project11Tests: XCTestCase {
    override func setUp() {
    }

    override func tearDown() {
    }

    func testHello() {
        XCTAssertEqual("Hello", "Hello", "Hello should equal Hello")
    }

    static var allTests : [(String, (project11Tests) -> () throws -> Void)] {
        return [
            ("testHello", testHello),
        ]
    }
}
