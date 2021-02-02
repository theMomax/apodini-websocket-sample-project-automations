//
//  DeviceHandlers.swift
//  
//
//  Created by Max Obermeier on 02.02.21.
//

import Apodini
import NIO

struct DeviceSetupConfiguration<D: Device>: Configuration {
    struct _DeviceDefinition: Codable {
        var id: String
        var channels: [String]
        var subscribe: String
        var update: String
    }
    
    struct _RegisterEndpointInput: Codable {
        var device: _DeviceDefinition
    }
    
    let id: String
    let device: D
    
    func configure(_ app: Application) {
        print("Setup \(id)")
        let result: Bool = try! StatelessClient(on: app.eventLoopGroup.next(), ignoreErrors: false).resolve(
           one: _RegisterEndpointInput(device: _DeviceDefinition(
               id: id,
               channels: device.channels,
               subscribe: "http://localhost:7001/v1/\(id)/subscribe/<CHANNEL>",
               update: "http://localhost:7001/v1/\(id)/update/<CHANNEL>?value=<VALUE>")),
            on: "v1.device").wait()
        _ = result
    }
}
struct SetupHandler<D: Device>: Handler {
    var device: D
    var deviceId: String
    
    struct _DeviceDefinition: Codable {
        var id: String
        var channels: [String]
        var subscribe: String
        var update: String
    }
    
    struct _RegisterEndpointInput: Codable {
        var device: _DeviceDefinition
    }
    
    @Environment(\.eventLoopGroup) var eventLoopGroup: EventLoopGroup
    
    func handle() throws -> EventLoopFuture<Bool> {
        print("Setup \(deviceId)")
        return StatelessClient(on: eventLoopGroup.next(), ignoreErrors: false).resolve(
            one: _RegisterEndpointInput(device: _DeviceDefinition(
                id: deviceId,
                channels: device.channels,
                subscribe: "http://localhost:7001/v1/\(deviceId)/subscribe/<CHANNEL>",
                update: "http://localhost:7001/v1/\(deviceId)/update/<CHANNEL>?value=<VALUE>")),
            on: "v1.device")
    }
}

struct SubscriptionHandler<D: Subscribable>: Handler {
    @Throws(.badInput, reason: "This device does not have a channel with the given id.") var unknownChannelError: ApodiniError
    
    @Parameter var channelId: String
    
    @Environment(\.eventLoopGroup) var eventLoopGroup: EventLoopGroup
    
    var device: D
    var id: String
    
    struct _ChannelInputHandlerInput: Codable {
        var deviceId: String
        var channelId: String
        var value: Double
    }
    
    func handle() throws -> Bool {
        print("Subscription \(channelId)")
        guard let publisher = device.subscribe(to: channelId) else {
            throw unknownChannelError
        }
        let eventLoop = eventLoopGroup.next()
        
        StatelessClient(on: eventLoop, ignoreErrors: false).resolve([String].self, from: publisher.map { value in
            _ChannelInputHandlerInput(deviceId: id, channelId: channelId, value: value)
        }, on: "v1.channel")
        
        return true
    }
}

struct UpdateHandler<D: Updatable>: Handler {
    @Throws(.badInput, reason: "This device does not have a channel with the given id.") var unknownChannelError: ApodiniError
    
    @Parameter var channelId: String
    
    @Parameter var value: Double
    
    var device: D
    
    func handle() throws -> Bool {
        print("Update \(channelId) to \(value)")
        guard device.update(channel: channelId, with: value) else {
            throw unknownChannelError
        }
        
        return true
    }
}

struct RetrieveHandler<D: Retrievable>: Handler {
    @Throws(.badInput, reason: "This device does not have a channel with the given id.") var unknownChannelError: ApodiniError
    
    @Parameter var channelId: String
    
    var device: D
    
    func handle() throws -> Double {
        print("Retrieve \(channelId)")
        guard let value = device.retrieve(channel: channelId) else {
            throw unknownChannelError
        }
        
        return value
    }
}

