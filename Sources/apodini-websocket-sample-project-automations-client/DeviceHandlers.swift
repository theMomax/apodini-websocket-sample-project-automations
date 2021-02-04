//
//  DeviceHandlers.swift
//  
//
//  Created by Max Obermeier on 02.02.21.
//

import Apodini
import NIO
import OpenCombine

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
        guard let publisher = device.subscribe(to: channelId) else {
            throw unknownChannelError
        }
        let eventLoop = eventLoopGroup.next()
        
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
                input.send(completion: .finished)
            case .updateMe:
                publisher.sink(receiveCompletion: { completion in
                    input.send(completion: completion)
                }, receiveValue: { value in
                    input.send(_ChannelHandlerInput(deviceId: id, channelId: channelId, value: value))
                }).store(in: &cancellables)
            case .update(let value):
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
