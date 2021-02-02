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
    var configuration: Configuration {
        HTTPConfiguration().address(.hostname("localhost", port: 7001))
    }
    
    @PathParameter var channelId: String
    
    let outlet = MockOutletDevice(on: 0, power: 0.0)
    
    var content: some Component {
        Group("outlet") {
            Group("setup") {
                SetupHandler(device: outlet, deviceId: "outlet")
            }
            Group("subscribe", $channelId) {
                SubscriptionHandler(channelId: $channelId, device: outlet)
            }
            Group("update", $channelId) {
                UpdateHandler(channelId: $channelId, device: outlet)
            }
            Group("retrieve", $channelId) {
                RetrieveHandler(channelId: $channelId, device: outlet)
            }
        }
    }
}

try ClientService.main()
