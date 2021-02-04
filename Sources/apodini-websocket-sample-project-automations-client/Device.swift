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
            if on.value == value {
                return true
            }
            on.value = value
        case "power":
            if power.value == value {
                return true
            }
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

// MARK: Lamp

class MockLampDevice: Device {
    var on: CurrentValueSubject<Double, Never>
    
    var channels: [String] {
        ["on"]
    }
    
    init(on: Double) {
        self.on = CurrentValueSubject(on)
    }
    
    func subscribe(to channel: String) -> AnyPublisher<Double, Never>? {
        switch channel {
        case "on":
            return on.eraseToAnyPublisher()
        default:
            return nil
        }
    }
    
    func update(channel: String, with value: Double) -> Bool {
        switch channel {
        case "on":
            if on.value == value {
                return true
            }
            on.value = value
            if value == 0 {
                if let lampOff = Bundle.module.path(forResource: "lamp-off", ofType: "jpg") {
                    shell("open", lampOff)
                }
            } else {
                if let lampOff = Bundle.module.path(forResource: "lamp-on", ofType: "jpg") {
                    shell("open", lampOff)
                }
            }
        default:
            return false
        }
        return true
    }
    
    func retrieve(channel: String) -> Double? {
        switch channel {
        case "on":
            return on.value
        default:
            return nil
        }
    }
}

// MARK: MotionDetector

class MockMotionDetectorDevice: Device {
    var triggered: CurrentValueSubject<Double, Never>
    
    var channels: [String] {
        ["triggered"]
    }
    
    init(triggered: Double) {
        self.triggered = CurrentValueSubject(triggered)
    }
    
    func subscribe(to channel: String) -> AnyPublisher<Double, Never>? {
        switch channel {
        case "triggered":
            return triggered.eraseToAnyPublisher()
        default:
            return nil
        }
    }
    
    func update(channel: String, with value: Double) -> Bool {
        switch channel {
        case "triggered":
            if triggered.value == value {
                return true
            }
            triggered.value = value
        default:
            return false
        }
        return true
    }
    
    func retrieve(channel: String) -> Double? {
        switch channel {
        case "triggered":
            return triggered.value
        default:
            return nil
        }
    }
}

@discardableResult
private func shell(_ args: String...) -> Int32 {
    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = args
    task.launch()
    task.waitUntilExit()
    return task.terminationStatus
}

