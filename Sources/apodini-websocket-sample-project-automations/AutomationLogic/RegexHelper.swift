//
//  File.swift
//  
//
//  Created by Max Obermeier on 19.01.21.
//

import Foundation

infix operator ~~ : MultiplicationPrecedence
extension String {
    // adapted from https://stackoverflow.com/a/53652037/9816338
    static func ~~ (lhs: String, rhs: NSRegularExpression) -> [[String]] {
        let text = lhs
        let regex = rhs
        let matches = regex.matches(in: text,
                                    range: NSRange(text.startIndex..., in: text))
        return matches.map { match in
            return (1..<match.numberOfRanges).map {
                let rangeBounds = match.range(at: $0)
                guard let range = Range(rangeBounds, in: text) else {
                    return ""
                }
                return String(text[range])
            }
        }
    }
}

