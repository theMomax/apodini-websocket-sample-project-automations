//
//  ChannelInputHandler.swift
//  
//
//  Created by Max Obermeier on 19.01.21.
//

import Apodini

enum ChannelReceptionResponse: String, Content {
    /// The channel was expected to be opened and is required.
    case ok
    /// The channel was never or is no longer required an can be
    /// closed.
    case notRequired
    /// The channel is still needed, do reopen as soon as possible.
    case reconnect
}

struct ChannelReceptionHandler: Handler {
    @Parameter(.mutability(.constant)) var deviceId: String
    @Parameter(.mutability(.constant)) var channelId: String
    
    @Parameter var value: Double
    
    @Environment(\.connection) var connection: Connection
    
    @State var acknowledged: Bool = false
    
    @Environment(\.automationStore) var automationStore: AutomationStore

    func handle() -> Response<ChannelReceptionResponse> {
        print("\(deviceId)/\(channelId) = \(value) (acknowledged=\(acknowledged); connection=\(connection.state))")
        if !automationStore.updateValue(value, for: Channel(deviceId: deviceId, channelId: channelId)) {
            return .final(.notRequired)
        } else {
            if connection.state == .end {
                return .final(.reconnect)
            } else {
                if acknowledged {
                    return .nothing
                } else {
                    acknowledged = true
                    return .send(.ok)
                }
            }
        }
    }
}
