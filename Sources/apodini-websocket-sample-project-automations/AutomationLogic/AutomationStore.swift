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
    
    private var channelsRequiredToBeConnected: Set<Channel> {
        automations.reduce(Set<Channel>(), { a, c in
            a.union(c.automation.channelsRequiredToBeConnected)
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
                evaluate(automation.automation)
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
                if device.channels[requiredToBeRegistered.channelId] == nil {
                    throw AutomationRegistrationError.channelNotRegistered(requiredToBeRegistered)
                }
            }
            automations.insert(IdentifiyableAutomation(automation: automation, uuid: uuid))
            evaluate(automation)
        }
    }
    
    func mustBeSubscribed(_ channel: Channel) -> Bool {
        self.channelsRequiredToBeSubscribed.contains(channel)
    }
    
    func mustBeConnected(_ channel: Channel) -> Bool {
        self.channelsRequiredToBeConnected.contains(channel)
    }
    
    func registerChannel(observable: ObservableChannel, mode: ChannelMode, on channel: Channel) -> Bool {
        guard let device = self.devices.get(device: channel.deviceId) else {
            return false
        }
        
        guard let channel = device.channels[channel.channelId] else {
            return false
        }
        
        channel.register(observable, mode)
        return true
    }
    
    private func evaluate(_ automation: Automation) {
        do {
            let updates = try automation.evaluate(with: values)
            for update in updates {
                guard let device = devices.get(device: update.channel.deviceId) else {
                    fatalError("Channels that are required to be subscribed should be a subset of the channels required to be registered!")
                }
                device.channels[update.channel.channelId]?.update(to: update.value, using: self.client)?.whenComplete { result in
                    switch result {
                    case .success(_):
                        self.logger.debug("Requested channel \(update.channel) to connect.")
                    case .failure(let error):
                        self.logger.error("Error sending Connect Message: \(error)")
                    }
                }
                
            }
        } catch (AutomationEvaluationError.missingChannel(let channel)) {
            guard let device = devices.get(device: channel.deviceId) else {
                fatalError("Channels that are required to be subscribed should be a subset of the channels required to be registered!")
            }
            device.channels[channel.channelId]?.connect(using: self.client).whenComplete { result in
                switch result {
                case .success(_):
                    self.logger.debug("Sent Connect Message: \(channel)")
                case .failure(let error):
                    self.logger.error("Error sending Connect Message: \(error)")
                }
            }
        } catch {
            logger.critical("Unexpected Error: \(error)")
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
    static var defaultValue: AutomationStore?
}

extension Application {
    var automationStore: AutomationStore {
        get { AutomationStoreKey.defaultValue! }
        set { AutomationStoreKey.defaultValue = newValue }
    }
}

struct AutomationStoreConfiguration: Configuration {
    func configure(_ app: Application) {
        let store = AutomationStore(devices: DeviceStoreKey.defaultValue, client: HTTPClient(eventLoopGroupProvider: .shared(app.eventLoopGroup)))
        
        app.automationStore = store
    }
}
