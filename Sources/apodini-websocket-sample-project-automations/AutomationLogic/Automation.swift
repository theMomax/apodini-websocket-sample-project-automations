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

// MARK: Automation

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

// MARK: Statement

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

// MARK: Condition

private struct Condition: LosslessStringConvertible {
    private static let regex = try! NSRegularExpression(pattern: "^(.+)\\s(.+)\\s(.+)$")
    
    private let expression1: Expression
    
    private let expression2: Expression
    
    private let comparator: Comparator
    
    init?(_ description: String) {
        guard let match = (description ~~ Self.regex).first else {
            return nil
        }
        
        guard let expression1 = Expression(match[0]) else {
            return nil
        }
        self.expression1 = expression1
        
        guard let comparator = Comparator(match[1]) else {
            return nil
        }
        self.comparator = comparator
        
        guard let expression2 = Expression(match[2]) else {
            return nil
        }
        self.expression2 = expression2
    }
    
    var description: String {
        "\(expression1.description) \(comparator.description) \(expression2.description)"
    }
}

// MARK: Expression

private indirect enum Expression: LosslessStringConvertible {
    case channel(Channel)
    case value(Double)
    case expression(Expression, Operator, Expression)
    
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
        case let .expression(lhs, `operator`, rhs):
            return "(\(lhs.description)) \(`operator`.description) (\(rhs.description))"
        }
    }
}

// MARK: Comparator

private enum Comparator: LosslessStringConvertible {
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

private enum Operator: LosslessStringConvertible {
    case plus, minus, times, divide
    
    init?(_ description: String) {
        switch description {
        case "+":
            self = .plus
        case "-":
            self = .minus
        case "*":
            self = .times
        case "/":
            self = .divide
        default:
            return nil
        }
    }
    
    var description: String {
        switch self {
        case .plus:
            return "+"
        case .minus:
            return "-"
        case .times:
            return "*"
        case .divide:
            return "/"
        }
    }
}

// MARK: Action

private struct Action: LosslessStringConvertible {
    private static let regex = try! NSRegularExpression(pattern: "^(.+)\\s=\\s(.+)$")
    
    private let channel: Channel
    
    private let expression: Expression
    
    init?(_ description: String) {
        guard let match = (description ~~ Self.regex).first else {
            return nil
        }
        
        guard let channel = Channel(match[0]) else {
            return nil
        }
        self.channel = channel
        
        guard let expression = Expression(match[1]) else {
            return nil
        }
        self.expression = expression
    }
    
    var description: String {
        "\(channel) = \(expression)"
    }
}

// MARK: Channel

struct Channel {
    let deviceId: String
    
    let channelId: String
    
    internal init(deviceId: String, channelId: String) {
        self.deviceId = deviceId
        self.channelId = channelId
    }
}

extension Channel: LosslessStringConvertible {
    private static let regex = try! NSRegularExpression(pattern: "^([[:alnum:]]+):([[:alnum:]]+)$")
    
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

extension Channel: Hashable { }

// MARK: Automation Evaluation

enum AutomationEvaluationError: Error {
    case missingChannel(Channel)
}


extension Automation {
    func evaluate(with values: [Channel:Double]) throws -> [(channel: Channel, value: Double)] {
        try self.statement.evaluate(with: values)
    }
}

extension Statement {
    func evaluate(with values: [Channel:Double]) throws -> [(channel: Channel, value: Double)] {
        if try self.condition.evaluate(with: values) {
            return [try self.action.evaluate(with: values)]
        }
        return []
    }
}

extension Condition {
    func evaluate(with values: [Channel:Double]) throws -> Bool {
        let value1 = try expression1.evaluate(with: values)
        let value2 = try expression2.evaluate(with: values)
        
        return self.comparator.evaluate(lhs: value1, rhs: value2)
    }
}

extension Action {
    func evaluate(with values: [Channel:Double]) throws -> (channel: Channel, value: Double) {
        (channel: self.channel, value: try self.expression.evaluate(with: values))
    }
}

extension Expression {
    func evaluate(with values: [Channel:Double]) throws -> Double {
        switch self {
        case .value(let value):
            return value
        case .channel(let channel):
            guard let value = values[channel] else {
                throw AutomationEvaluationError.missingChannel(channel)
            }
            return value
        case let .expression(lhs, `operator`, rhs):
            return `operator`.evaluate(lhs: try lhs.evaluate(with: values), rhs: try rhs.evaluate(with: values))
        }
    }
}

extension Comparator {
    func evaluate(lhs: Double, rhs: Double) -> Bool {
        switch self {
        case .equal:
            return lhs == rhs
        case .unequal:
            return lhs != rhs
        case .lower:
            return lhs < rhs
        case .greater:
            return lhs > rhs
        case .lowerEqual:
            return lhs <= rhs
        case .greaterEqual:
            return lhs >= rhs
        }
    }
}

extension Operator {
    func evaluate(lhs: Double, rhs: Double) -> Double {
        switch self {
        case .plus:
            return lhs + rhs
        case .minus:
            return lhs - rhs
        case .times:
            return lhs * rhs
        case .divide:
            if rhs == 0.0 {
                return lhs * Double.infinity
            }
            return lhs / rhs
        }
    }
}


// MARK: Channel Retrieving

extension Automation {
    var channelsRequiredToBeRegistered: Set<Channel> {
        statement.channelsRequiredToBeRegistered
    }
}

extension Statement {
    var channelsRequiredToBeRegistered: Set<Channel> {
        condition.channelsRequiredToBeRegistered + action.channelsRequiredToBeRegistered
    }
}

extension Action {
    var channelsRequiredToBeRegistered: Set<Channel> {
        expression.channelsRequiredToBeRegistered
    }
}

extension Condition {
    var channelsRequiredToBeRegistered: Set<Channel> {
        expression1.channelsRequiredToBeRegistered + expression2.channelsRequiredToBeRegistered
    }
}

extension Expression {
    var channelsRequiredToBeRegistered: Set<Channel> {
        switch self {
        case .channel(let channel):
            return [channel]
        case .value(_):
            return []
        case let .expression(lhs, _, rhs):
            return lhs.channelsRequiredToBeRegistered + rhs.channelsRequiredToBeRegistered
        }
    }
}


extension Automation {
    var channelsRequiredToBeSubscribed: Set<Channel> {
        statement.channelsRequiredToBeSubscribed
    }
}

extension Statement {
    var channelsRequiredToBeSubscribed: Set<Channel> {
        condition.channelsRequiredToBeSubscribed
    }
}

extension Action {
    var channelsRequiredToBeSubscribed: Set<Channel> {
        []
    }
}

extension Condition {
    var channelsRequiredToBeSubscribed: Set<Channel> {
        expression1.channelsRequiredToBeSubscribed + expression2.channelsRequiredToBeSubscribed
    }
}

extension Expression {
    var channelsRequiredToBeSubscribed: Set<Channel> {
        switch self {
        case .channel(let channel):
            return [channel]
        case .value(_):
            return []
        case let .expression(lhs, _, rhs):
            return lhs.channelsRequiredToBeSubscribed + rhs.channelsRequiredToBeSubscribed
        }
    }
}

private extension Set {
    static func + (lhs: Self, rhs: Self) -> Self {
        lhs.union(rhs)
    }
}
