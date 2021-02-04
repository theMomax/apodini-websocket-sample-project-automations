//
//  ChannelHandler.swift
//  
//
//  Created by Max Obermeier on 19.01.21.
//

import Apodini

enum ChannelResponse: Content {
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
}

struct ChannelHandler: Handler {
    @Throws(.badInput, reason: "No value was provided.") var noValueError: ApodiniError
    @Throws(.badInput, reason: "Unknown device or channel") var unknownChannelError: ApodiniError
    
    @Parameter(.mutability(.constant)) var deviceId: String
    @Parameter(.mutability(.constant)) var channelId: String
    
    @Parameter var value: Double?
    
    @Environment(\.connection) var connection: Connection
    
    @Initial var initial: Bool
    
    @Environment(\.automationStore) var automationStore: AutomationStore
    
    @ObservedObject var observableChannel = ObservableChannel()
    
    @ObservedObject var channelMode = ChannelMode()

    func handle() throws -> Response<ChannelResponse> {
        let channel = Channel(deviceId: deviceId, channelId: channelId)
        
        if connection.state == .end && automationStore.mustBeConnected(channel) {
            return .final(.reconnect)
        }
        
        if !automationStore.mustBeConnected(channel) {
            return .final(.notRequired)
        }
        
        if initial {
            if !automationStore.registerChannel(observable: observableChannel, mode: channelMode, on: channel) {
                throw unknownChannelError
            }
            
            if automationStore.mustBeSubscribed(channel) {
                return .send(.updateMe)
            } else {
                return .nothing
            }
        }
        
        if (_channelMode.changed && channelMode.mustBeSubscribed) {
            return .send(.updateMe)
        }
        
        if (_observableChannel.changed) {
            return .send(.update(observableChannel.value))
        }
        
        guard let value = value else {
            throw noValueError
        }
        
        _ = automationStore.updateValue(value, for: channel)
        
        return .nothing
    }
}
