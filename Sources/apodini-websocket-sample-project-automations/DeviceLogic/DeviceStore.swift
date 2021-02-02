//
//  DeviceStore.swift
//  
//
//  Created by Max Obermeier on 24.01.21.
//

import Foundation
import Logging
import Apodini

class DeviceStore {
    
    private let logger: Logger = .init(label: "device_store")
    
    private let _lock = NSLock()
    
    private var devices: [String: Device] = [:]
    
    private var values: [Channel: Double] = [:]
    
    func register(_ device: Device) {
        _lock.guard {
            devices[device.id] = device
        }
    }
    
    func get(device id: String) -> Device? {
        _lock.guard {
            devices[id]
        }
    }
}

// MARK: Evnironment Access

struct DeviceStoreKey: StorageKey {
    typealias Value = DeviceStore
    static var defaultValue = DeviceStore()
}

extension Application {
    var deviceStore: DeviceStore {
        get { DeviceStoreKey.defaultValue }
    }
}
