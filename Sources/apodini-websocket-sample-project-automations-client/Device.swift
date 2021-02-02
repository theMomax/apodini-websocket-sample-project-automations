//
//  Device.swift
//  
//
//  Created by Max Obermeier on 02.02.21.
//

import Foundation
import OpenCombine


protocol Subscribable {
    func subscribe(to channel: String) -> AnyPublisher<Double, Never>?
}

protocol Updatable {
    func update(channel: String, with value: Double) -> Bool
}

protocol Retrievable {
    func retrieve(channel: String) -> Double?
}

protocol Device: Subscribable, Updatable, Retrievable {
    var channels: [String] { get }
}

// MARK: Outlet

class MockOutletDevice: Device {
    var on: CurrentValueSubject<Double, Never>
    var power: CurrentValueSubject<Double, Never>
    
    var channels: [String] {
        ["on", "power"]
    }
    
    init(on: Double, power: Double) {
        self.on = CurrentValueSubject(on)
        self.power = CurrentValueSubject(power)
    }
    
    func subscribe(to channel: String) -> AnyPublisher<Double, Never>? {
        switch channel {
        case "on":
            return on.eraseToAnyPublisher()
        case "power":
            return power.eraseToAnyPublisher()
        default:
            return nil
        }
    }
    
    func update(channel: String, with value: Double) -> Bool {
        switch channel {
        case "on":
            on.value = value
        case "power":
            power.value = value
        default:
            return false
        }
        return true
    }
    
    func retrieve(channel: String) -> Double? {
        switch channel {
        case "on":
            return on.value
        case "power":
            return power.value
        default:
            return nil
        }
    }
}
