//
//  main.swift
//  
//
//  Created by Max Obermeier on 02.02.21.
//

import OpenCombine
import Apodini
import NIO

struct ClientService: Apodini.WebService {
    let outlet = MockOutletDevice(on: 0, power: 0.0)
    let lamp = MockLampDevice(on: 0)
    let motionDetector = MockMotionDetectorDevice(triggered: 0)
    
    var configuration: Configuration {
        HTTPConfiguration().address(.hostname("localhost", port: 7001))
        DeviceSetupConfiguration(id: "lamp", device: lamp)
        DeviceSetupConfiguration(id: "outlet", device: outlet)
        DeviceSetupConfiguration(id: "motiondetector", device: motionDetector)
    }
    
    var content: some Component {
        DeviceComponent(device: lamp, id: "lamp")
        DeviceComponent(device: outlet, id: "outlet")
        DeviceComponent(device: motionDetector, id: "motiondetector")
    }
}

struct DeviceComponent<D: Device>: Component {
    
    var device: D
    
    var id: String
    
    @PathParameter var channelId: String
    
    var content: some Component {
        Group(id) {
            Group("subscribe", $channelId) {
                SubscriptionHandler(channelId: $channelId, device: device, id: id)
            }
            Group("update", $channelId) {
                UpdateHandler(channelId: $channelId, device: device)
            }
            Group("retrieve", $channelId) {
                RetrieveHandler(channelId: $channelId, device: device)
            }
        }
    }
}

try ClientService.main()
