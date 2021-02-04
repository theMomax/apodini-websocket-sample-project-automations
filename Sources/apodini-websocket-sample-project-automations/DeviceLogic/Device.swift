//
//  Device.swift
//  
//
//  Created by Max Obermeier on 24.01.21.
//

import Foundation
import AsyncHTTPClient
import NIO
import Apodini

enum DeviceDecodingError: Error {
    case unableToDecode(String)
}

protocol Device {
    var id: String { get }
    
    var channels: [String: ChannelBinding] { get }
}

class ChannelBinding {
    private var connectAddress: String
    
    private var value: Double?
    
    private weak var observable: ObservableChannel? {
        didSet {
            if let value = value {
                observable?.value = value
            }
        }
    }
    
    private weak var mode: ChannelMode?
    
    init(_ connectAddress: String) {
        self.connectAddress = connectAddress
    }
    
    func update(to value: Double, using client: HTTPClient) -> EventLoopFuture<Void>? {
        self.value = value
        if let observable = self.observable {
            observable.value = value
            return nil
        } else {
            return self.connect(using: client)
        }
    }
    
    func register(_ observable: ObservableChannel, _ mode: ChannelMode) {
        self.observable = observable
        self.mode = mode
    }
    
    func connect(using client: HTTPClient) -> EventLoopFuture<Void> {
        return client.get(url: connectAddress).transform(to: Void())
    }
}

class ObservableChannel: Apodini.ObservableObject {
    @Apodini.Published var value: Double = 0
}

class ChannelMode: Apodini.ObservableObject {
    @Apodini.Published var mustBeSubscribed: Bool = false
}

struct DeviceDefinition: Device {
    var id: String
    
    var channels: [String: ChannelBinding]
    
    private var rawAddress: String
}

extension DeviceDefinition: Codable {
    struct _DeviceDefinition: Codable {
        static let channelPlaceholder: String = "<CHANNEL>"
        
        var id: String
        var channels: [String]
        var address: String
    }
    
    init(from decoder: Decoder) throws {
        let definition = try _DeviceDefinition(from: decoder)
        
        self.id = definition.id
        
        self.rawAddress = definition.address
        
        var channels: [String: ChannelBinding] = [:]
        
        for channel in definition.channels {
            channels[channel] = ChannelBinding(definition.address.replacingOccurrences(of: _DeviceDefinition.channelPlaceholder, with: channel))
        }
        
        self.channels = channels
    }
    
    func encode(to encoder: Encoder) throws {
        try _DeviceDefinition(id: id, channels: Array(channels.keys), address:  rawAddress).encode(to: encoder)
    }
}
