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
        // in case the client unexpectedly wants to disconnect we tell it to reconnect ASAP
        if connection.state == .end && automationStore.mustBeConnected(channel) {
            return .final(.reconnect)
        }
        // in case no automation depends on this channel we close the connection
        if !automationStore.mustBeConnected(channel) {
            return .final(.notRequired)
        }
        
        // on the first evaluation we have to do some setup-tasks
        if initial {
            // first we pass the `ObservedObject`s to the service-layer so it can notify us asynchronically about
            // updates regarding the channel's value or the channel's requirements
            if !automationStore.registerChannel(observable: observableChannel, mode: channelMode, on: channel) {
                throw unknownChannelError
            }
            // if there is an automation which's condition depends on this channel we tell the client it has
            // to update us whenever its value changes
            if automationStore.mustBeSubscribed(channel) {
                return .send(.updateMe)
            } else {
                return .nothing
            }
        }
        
        // in case this channel was first only used to update the client when the value was changed by an automation,
        // but now it is also used in an automation's condition, we need to tell the client it now also needs to
        // send updates
        if (_channelMode.changed && channelMode.mustBeSubscribed) {
            return .send(.updateMe)
        }
        
        // an automation changed the channel's value, so we tell the client
        if (_observableChannel.changed) {
            return .send(.update(observableChannel.value))
        }
        
        // at this point we know that this evaluation was caused by a client message (not the initial one), which
        // always have to update the value
        guard let value = value else {
            throw noValueError
        }
        // we pass the update to the service-layer without responding
        _ = automationStore.updateValue(value, for: channel)
        return .nothing
    }
}
