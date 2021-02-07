//
//  DeviceHandlers.swift
//  
//
//  Created by Max Obermeier on 02.02.21.
//

import Apodini
import NIO
import OpenCombine

// registers the device to the Hub server
struct DeviceSetupConfiguration<D: Device>: Configuration {
    struct _DeviceDefinition: Codable {
        var id: String
        var channels: [String]
        var address: String
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
            address: "http://localhost:7001/v1/\(id)/connect/<CHANNEL>")),
       on: "v1.device").wait()
        _ = result
    }
}

struct ConnectionHandler<D: Device>: Handler {
    @Throws(.badInput, reason: "This device does not have a channel with the given id.") var unknownChannelError: ApodiniError
    
    @Parameter var channelId: String
    
    @Environment(\.eventLoopGroup) var eventLoopGroup: EventLoopGroup
    
    var device: D
    var id: String
    
    func handle() throws -> Bool {
        print("Connection \(channelId)")
        // get a publisher that fires when the requested channel's value is updated
        guard let publisher = device.subscribe(to: channelId) else {
            throw unknownChannelError
        }
        
        // setup a WebSocket client that communicates with the Hub's `/v1/channel` enpoint
        let eventLoop = eventLoopGroup.next()
        
        // This publisher is passed into the client. It sends an initial message with `value = nil`. Later on we just pass in updates from
        // the channel's `publisher` we previously obtained from the `device`.
        let input = CurrentValueSubject<_ChannelHandlerInput, Never>(_ChannelHandlerInput(deviceId: id, channelId: channelId, value: nil))
        
        var cancellables = Set<AnyCancellable>()
        
        StatelessClient(on: eventLoop, ignoreErrors: true).resolve(_ChannelResponse.self, from: input, on: "v1.channel").sink(receiveCompletion: { completion in
            switch completion {
            case .failure(let error):
                fatalError("\(error)")
            case .finished:
                break
            }
            cancellables.removeAll()
        }, receiveValue: { value in
            switch value {
            case .notRequired:
                // this connection is not needed anymore, so we close it
                input.send(completion: .finished)
            case .updateMe:
                // the Hub now also wants to receive updates from our side
                // regarding the channel's value, so we pipe the channel's `publisher`'s
                // output into the `StatelessClient`'s `input`
                publisher.sink(receiveCompletion: { completion in
                    input.send(completion: completion)
                }, receiveValue: { value in
                    input.send(_ChannelHandlerInput(deviceId: id, channelId: channelId, value: value))
                }).store(in: &cancellables)
            case .update(let value):
                // an automation caused this channel's value to change, so we update the device's state
                
                // the `update` function makes sure the `publisher` is not triggered if the value hasn't
                // really changed
                _ = device.update(channel: channelId, with: value)
            default:
                break
            }
        }).store(in: &cancellables)
        
        return true
    }
    
    struct _ChannelHandlerInput: Codable {
        var deviceId: String
        var channelId: String
        var value: Double?
    }
    
    enum _ChannelResponse: Content, Decodable {
        /// The client shall send a message with the new value every time
        /// it changes the channel's value.
        case updateMe
        /// An automation has caused this channel's value to change.
        case update(Double)
        /// The channel was never or is no longer required an can be
        /// closed.
        case notRequired
        /// The channel is still needed, do reopen as soon as possible.
        case reconnect
        
        func encode(to encoder: Encoder) throws {
            switch self {
            case .update(let value):
                try value.encode(to: encoder)
            case .updateMe:
                try "updateMe".encode(to: encoder)
            case .notRequired:
                try "notRequired".encode(to: encoder)
            case .reconnect:
                try "reconnect".encode(to: encoder)
            }
        }
        
        init(from decoder: Decoder) throws {
            if let value = try? Double(from: decoder) {
                self = .update(value)
            } else {
                let stringValue = try String(from: decoder)
                
                switch stringValue {
                case "updateMe":
                    self = .updateMe
                case "notRequired":
                    self = .notRequired
                case "reconnect":
                    self = .reconnect
                default:
                    throw DecodingError.typeMismatch(Self.self, DecodingError.Context(codingPath: [], debugDescription: "Wrong enum value \(stringValue)"))
                }
            }
        }
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
