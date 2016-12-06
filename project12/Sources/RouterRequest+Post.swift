//
//  RouterRequest+Post.swift
//  project11
//
//  Created by Paul Hudson on 05/12/2016.
//
//

import Foundation
import Kitura

extension RouterRequest {
    func getPost(fields: [String]) -> [String: String]? {
        guard let values = self.body else { return nil }

        let removeHTMLEncoding: Bool
        let submittedFields: [String: String]

        if case .urlEncoded(let body) = values {
            submittedFields = body
            removeHTMLEncoding = true
        } else if case .json(let body) = values {
            guard let unwrapped = body.dictionaryObject as? [String: String] else { return nil }
            submittedFields = unwrapped
            removeHTMLEncoding = false
        } else {
            return nil
        }

        var result = [String: String]()

        for field in fields {
            if let value = submittedFields[field]?.trimmingCharacters(in: .whitespacesAndNewlines) {
                if value.characters.count > 0 {
                    if removeHTMLEncoding {
                        result[field] = value.removingHTMLEncoding()
                    } else {
                        result[field] = value
                    }
                    continue
                }
            }
            
            return nil
        }
        
        return result
    }
}
