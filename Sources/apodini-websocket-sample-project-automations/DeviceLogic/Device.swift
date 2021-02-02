//
//  Device.swift
//  
//
//  Created by Max Obermeier on 24.01.21.
//

import Foundation
import AsyncHTTPClient
import NIO

enum DeviceDecodingError: Error {
    case unableToDecode(String)
}

protocol Device: Subscribable, Updatable {
    var id: String { get }
    
    var channels: [String] { get }
}

struct DeviceDefinition: Device {
    var id: String
    
    var channels: [String]
    
    private var subscribable: SubscriptionInstruction
    
    private var updatable: UpdateInstruction
    
    func subscribe(to channel: String, using client: HTTPClient) -> EventLoopFuture<Void> {
        self.subscribable.subscribe(to: channel, using: client)
    }
    
    func update(_ channel: String, with value: Double, using client: HTTPClient) -> EventLoopFuture<Void> {
        self.updatable.update(channel, with: value, using: client)
    }
}

extension DeviceDefinition: Codable {
    struct _DeviceDefinition: Codable {
        var id: String
        var channels: [String]
        var subscribe: String
        var update: String
    }
    
    
    init(from decoder: Decoder) throws {
        let definition = try _DeviceDefinition(from: decoder)
        
        guard let subscribable = SubscriptionInstruction(definition.subscribe) else {
            throw DeviceDecodingError.unableToDecode(definition.subscribe)
        }
        
        guard let updatable = UpdateInstruction(definition.update) else {
            throw DeviceDecodingError.unableToDecode(definition.update)
        }
                
        self.init(id: definition.id, channels: definition.channels, subscribable: subscribable, updatable: updatable)
    }
    
    func encode(to encoder: Encoder) throws {
        try _DeviceDefinition(id: id, channels: channels, subscribe: subscribable.description, update: updatable.description).encode(to: encoder)
    }
}

protocol Subscribable {
    func subscribe(to channel: String, using client: HTTPClient) -> EventLoopFuture<Void>
}

protocol Updatable {
    func update(_ channel: String, with value: Double, using client: HTTPClient) -> EventLoopFuture<Void>
}

private struct SubscriptionInstruction: LosslessStringConvertible {
    static let channelPlaceholder: String = "<CHANNEL>"
    
    private let subscribeClosure: (String, HTTPClient) -> EventLoopFuture<Void>
    
    private let original: String
    
    init?(_ description: String) {
        self.original = description
        
        self.subscribeClosure = { channel, client in
            let url = description.replacingOccurrences(of: Self.channelPlaceholder, with: channel)
            return client.get(url: url).transform(to: Void())
        }
    }
    
    var description: String {
        original
    }
}

extension SubscriptionInstruction: Subscribable {
    func subscribe(to channel: String, using client: HTTPClient) -> EventLoopFuture<Void> {
        self.subscribeClosure(channel, client)
    }
}

private struct UpdateInstruction: LosslessStringConvertible {
    static let valuePlaceholder: String = "<VALUE>"
    static let channelPlaceholder: String = "<CHANNEL>"
    
    private let updateClosure: (String, Double, HTTPClient) -> EventLoopFuture<Void>
    
    private let original: String
    
    init?(_ description: String) {
        self.original = description
        
        self.updateClosure = { channel, value, client in
            let url = description.replacingOccurrences(of: Self.valuePlaceholder, with: String(format: "%f", value)).replacingOccurrences(of: Self.channelPlaceholder, with: channel)
            return client.get(url: url).transform(to: Void())
        }
    }
    
    var description: String {
        original
    }
}

extension UpdateInstruction: Updatable {
    func update(_ channel: String, with value: Double, using client: HTTPClient) -> EventLoopFuture<Void> {
        self.updateClosure(channel, value, client)
    }
}
