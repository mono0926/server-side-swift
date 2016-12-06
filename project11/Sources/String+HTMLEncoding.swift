//
//  String+HTMLEncoding.swift
//  project11
//
//  Created by Paul Hudson on 05/12/2016.
//
//

import Foundation

extension String {
    func removingHTMLEncoding() -> String {
        let result = self.replacingOccurrences(of: "+", with: " ")
        return result.removingPercentEncoding ?? result
    }
}
