//
//  AutomationStore.swift
//  
//
//  Created by Max Obermeier on 24.01.21.
//

import Foundation
import Logging
import AsyncHTTPClient
import Apodini

enum AutomationRegistrationError: LocalizedError {
    case deviceNotRegistered(String)
    case channelNotRegistered(Channel)
    
    var failureReason: String? {
        switch self {
        case .channelNotRegistered(let channel):
            return "Device \(channel.deviceId) does not have a channel \(channel.channelId)."
        case .deviceNotRegistered(let deviceId):
            return "Device \(deviceId) was not registered."
        }
    }
}

class AutomationStore {
    
    private let client: HTTPClient
    
    private let devices: DeviceStore
    
    private let logger: Logger = .init(label: "automation_store")
    
    private let _lock = NSLock()
    
    private var automations: Set<IdentifiyableAutomation> = []
    
    private var channelsRequiredToBeSubscribed: Set<Channel> {
        automations.reduce(Set<Channel>(), { a, c in
            a.union(c.automation.channelsRequiredToBeSubscribed)
        })
    }
    
    private var channelsRequiredToBeRegistered: Set<Channel> {
        automations.reduce(Set<Channel>(), { a, c in
            a.union(c.automation.channelsRequiredToBeRegistered)
        })
    }
    
    private var values: [Channel: Double] = [:]
    
    
    init(devices: DeviceStore, client: HTTPClient) {
        self.devices = devices
        self.client = client
    }
    
    
    func updateValue(_ value: Double, for channel: Channel) -> Bool {
        _lock.guard {
            guard self.channelsRequiredToBeSubscribed.contains(channel) else {
                return false
            }
            
            values[channel] = value
            
            for automation in automations {
                do {
                    let updates = try automation.automation.evaluate(with: values)
                    for update in updates {
                        guard let device = devices.get(device: update.channel.deviceId) else {
                            fatalError("Channels that are required to be subscribed should be a subset of the channels required to be registered!")
                        }
                        device.update(update.channel.channelId, with: update.value, using: self.client).whenComplete { result in
                            switch result {
                            case .success(_):
                                self.logger.debug("Sent Update Message: \(update.channel) = \(update.value)")
                            case .failure(let error):
                                self.logger.error("Error sending Update Message: \(error)")
                            }
                        }
                        
                    }
                } catch (AutomationEvaluationError.missingChannel(let channel)) {
                    guard let device = devices.get(device: channel.deviceId) else {
                        fatalError("Channels that are required to be subscribed should be a subset of the channels required to be registered!")
                    }
                    device.subscribe(to: channel.channelId, using: self.client).whenComplete { result in
                        switch result {
                        case .success(_):
                            self.logger.debug("Sent Subscripiton Request Message: \(channel)")
                        case .failure(let error):
                            self.logger.error("Error sending Subscription Request Message: \(error)")
                        }
                    }
                } catch {
                    logger.critical("Unexpected Error: \(error)")
                }
            }
            return true
        }
    }
    
    func addAutomation(_ automation: Automation, with uuid: UUID) throws {
        try _lock.guard {
            for requiredToBeRegistered in automation.channelsRequiredToBeRegistered {
                guard let device = devices.get(device: requiredToBeRegistered.deviceId) else {
                    throw AutomationRegistrationError.deviceNotRegistered(requiredToBeRegistered.deviceId)
                }
                if !device.channels.contains(requiredToBeRegistered.channelId) {
                    throw AutomationRegistrationError.channelNotRegistered(requiredToBeRegistered)
                }
            }
            for requiredToBeSubscribed in automation.channelsRequiredToBeSubscribed {
                guard let device = devices.get(device: requiredToBeSubscribed.deviceId) else {
                    fatalError("Channels that are required to be subscribed should be a subset of the channels required to be registered!")
                }
                device.subscribe(to: requiredToBeSubscribed.channelId, using: self.client).whenComplete { result in
                    self.logger.info("Sent subscription message to \(device.id)/\(requiredToBeSubscribed.channelId): \(result)")
                }
            }
            automations.insert(IdentifiyableAutomation(automation: automation, uuid: uuid))
        }
    }
    
    @discardableResult
    func removeAutomation(with uuid: UUID) -> Automation? {
        _lock.guard {
            let identifyableAutomation = automations.first(where: { automation in automation.uuid == uuid })
            
            guard let automation = identifyableAutomation else {
                return nil
            }
            
            return automations.remove(automation)?.automation
        }
    }
}

private struct IdentifiyableAutomation: Hashable {
    var automation: Automation
    var uuid: UUID
    
    var hashValue: Int { uuid.hashValue }
    
    func hash(into hasher: inout Hasher) {
        uuid.hash(into: &hasher)
    }
    
    static func == (lhs: IdentifiyableAutomation, rhs: IdentifiyableAutomation) -> Bool {
        lhs.uuid == rhs.uuid
    }
}

extension NSLock {
    @discardableResult
    func `guard`<T>( _ action: () throws -> T) rethrows -> T {
        self.lock()
        defer { self.unlock() }
        return try action()
    }
}


struct AutomationStoreKey: StorageKey {
    typealias Value = AutomationStore
    static var defaultValue = AutomationStore(devices: DeviceStoreKey.defaultValue, client: HTTPClient(eventLoopGroupProvider: .createNew))
}

extension Application {
    var automationStore: AutomationStore {
        get { AutomationStoreKey.defaultValue }
    }
}
