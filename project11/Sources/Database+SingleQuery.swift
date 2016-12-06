//
//  Database+SingleQuery.swift
//  project11
//
//  Created by Paul Hudson on 05/12/2016.
//
//

import Foundation
import MySQL

extension Database {
    func singleQuery(_ query: String, _ values: [NodeRepresentable] = [], _ connection: Connection? = nil) -> Node? {
        do {
            return try self.execute(query, values, connection).first?.first?.value
        } catch {
            return nil
        }
    }
}
