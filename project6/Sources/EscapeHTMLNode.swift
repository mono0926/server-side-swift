//
//  EscapeHTMLNode.swift
//  project6
//
//  Created by Paul Hudson on 03/12/2016.
//
//

import Stencil
import HTMLEntities

open class AutoescapeNode: NodeType {
    var nodesToEscape: [NodeType]

    public init(nodes: [NodeType]) {
        nodesToEscape = nodes
    }

    class func parse(_ parser: TokenParser, token: Token) throws -> NodeType {
        let nodes = try parser.parse(until(["endautoescape"]))

        guard let _ = parser.nextToken() else {
            throw TemplateSyntaxError("`endautoescape` was not found.")
        }

        return AutoescapeNode(nodes: nodes)
    }

    open func render(_ context: Context) throws -> String {
        let content = try renderNodes(nodesToEscape, context)
        return content.htmlEscape()
    }
}
