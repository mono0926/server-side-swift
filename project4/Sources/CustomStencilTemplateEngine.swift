/**
 * Copyright IBM Corporation 2015
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Foundation
import KituraTemplateEngine
import Stencil
import PathKit

public class CustomStencilTemplateEngine: TemplateEngine {
    public var fileExtension: String { return "stencil" }
    public init() {}

    public func render(filePath: String, context: [String: Any]) throws -> String {
        let templatePath = Path(filePath)
        let templateDirectory = templatePath.parent()
        let template = try Template(path: templatePath)
        let loader = FileSystemLoader(paths: [templateDirectory])
        var context = context
        context["loader"] = loader

        let namespace = Namespace()

        namespace.registerFilter("format_date") { (value: Any?) in
            if let value = value as? String {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

                if let date = formatter.date(from: value) {
                    formatter.dateStyle = .long
                    formatter.timeStyle = .medium
                    return formatter.string(from: date)
                }
            }
            
            return value
        }

        return try template.render(Context(dictionary: context, namespace: namespace))
    }
}
