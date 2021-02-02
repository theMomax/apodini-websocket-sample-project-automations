//
//  DeviceRegistrationHandler.swift
//  
//
//  Created by Max Obermeier on 19.01.21.
//

import Apodini

struct DeviceRegistrationHandler: Handler {
    @Throws(.badInput, reason: "A device with this id does already exist.") var duplicateDeviceError: ApodiniError
        
    @Parameter var device: DeviceDefinition
    
    @Environment(\.deviceStore) var deviceStore: DeviceStore
    
    func handle() throws -> Bool {
        guard deviceStore.get(device: device.id) == nil else {
            throw duplicateDeviceError
        }
        deviceStore.register(device)
        return true
    }
}
