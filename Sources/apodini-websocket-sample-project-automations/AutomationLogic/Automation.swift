//
//  Automation.swift
//  
//
//  Created by Max Obermeier on 19.01.21.
//

import Foundation
import Apodini

enum AutomationDecodingError: Error {
    case unableToDecode(String)
}

struct Automation: LosslessStringConvertible {
    private let statement: Statement
    
    init?(_ description: String) {
        guard let statement = Statement(description) else {
            return nil
        }
        self.statement = statement
    }
    
    var description: String {
        statement.description
    }
}

private struct Statement: LosslessStringConvertible {
    private static let regex = try! NSRegularExpression(pattern: "^(.+)\\s-->\\s(.+)$")
    
    private let condition: Condition
    
    private let action: Action
    
    init?(_ description: String) {
        guard let match = (description ~~ Self.regex).first else {
            return nil
        }
        
        guard let condition = Condition(match[0]) else {
            return nil
        }
        self.condition = condition
        
        guard let action = Action(match[1]) else {
            return nil
        }
        self.action = action
    }
    
    var description: String {
        "\(condition.description) --> \(action.description)"
    }
}

private struct Condition: LosslessStringConvertible {
    private static let regex = try! NSRegularExpression(pattern: "^(.+)\\s(.+)\\s(.+)$")
    
    private let expression1: Expression
    
    private let expression2: Expression
    
    private let `operator`: Operator
    
    init?(_ description: String) {
        guard let match = (description ~~ Self.regex).first else {
            return nil
        }
        
        guard let expression1 = Expression(match[0]) else {
            return nil
        }
        self.expression1 = expression1
        
        guard let `operator` = Operator(match[1]) else {
            return nil
        }
        self.operator = `operator`
        
        guard let expression2 = Expression(match[2]) else {
            return nil
        }
        self.expression2 = expression2
    }
    
    var description: String {
        "\(expression1.description) \(`operator`.description) \(expression2.description)"
    }
}

private enum Expression: LosslessStringConvertible {
    case channel(Channel)
    case value(Double)
    
    init?(_ description: String) {
        if let channel = Channel(description) {
            self = .channel(channel)
        } else if let value = Double(description) {
            self = .value(value)
        } else {
            return nil
        }
    }
    
    var description: String {
        switch self {
        case .channel(let channel):
            return channel.description
        case .value(let value):
            return value.description
        }
    }
}

private enum Operator: LosslessStringConvertible {
    case equal, unequal, lower, greater, lowerEqual, greaterEqual
    
    init?(_ description: String) {
        switch description {
        case "==":
            self = .equal
        case "!=":
            self = .unequal
        case "<":
            self = .lower
        case ">":
            self = .greater
        case "<=":
            self = .lowerEqual
        case ">=":
            self = .greaterEqual
        default:
            return nil
        }
    }
    
    var description: String {
        switch self {
        case .equal:
            return "=="
        case .unequal:
            return "!="
        case .greater:
            return ">"
        case .lower:
            return "<"
        case .greaterEqual:
            return ">="
        case .lowerEqual:
            return "<="
        }
    }
}

private struct Action: LosslessStringConvertible {
    private static let regex = try! NSRegularExpression(pattern: "^(.+)\\s=\\s(.+)$")
    
    private let channel: Channel
    
    private let value: Double
    
    init?(_ description: String) {
        guard let match = (description ~~ Self.regex).first else {
            return nil
        }
        
        guard let channel = Channel(match[0]) else {
            return nil
        }
        self.channel = channel
        
        guard let value = Double(match[1]) else {
            return nil
        }
        self.value = value
    }
    
    var description: String {
        "\(channel) = \(value)"
    }
}

private struct Channel: LosslessStringConvertible {
    private static let regex = try! NSRegularExpression(pattern: "^([[:alnum:]]+):([[:alnum:]]+)$")
    
    private let deviceId: String
    
    private let channelId: String
    
    init?(_ description: String) {
        guard let match = (description ~~ Self.regex).first else {
            return nil
        }
        
        self.deviceId = match[0]
        self.channelId = match[1]
    }
    
    var description: String {
        "\(deviceId):\(channelId)"
    }
}
