
import Apodini
import AsyncHTTPClient



//struct Stores: EnvironmentAccessible {
//    var automations: AutomationStore
//    var devices: DeviceStore
//}
//
//struct AutomationService: Apodini.WebService {
//    let deviceStore: DeviceStore
//    let automationStore: AutomationStore
//
//    init() {
//        let deviceStore = DeviceStore()
//
//        self.deviceStore = deviceStore
//        self.automationStore = AutomationStore(devices: deviceStore, client: HTTPClient(eventLoopGroupProvider: .createNew))
//    }
//
//    var configuration: Configuration {
//        EnvironmentObject(self.automationStore, \Stores.automations)
//        EnvironmentObject(self.deviceStore, \Stores.devices)
//    }

struct AutomationService: Apodini.WebService {
    var content: some Component {
        Group("channel") {
            ChannelReceptionHandler()
        }
        Group("automation") {
            AutomationRegistrationHandler()
        }
        Group("device") {
            DeviceRegistrationHandler()
        }
    }
}

try AutomationService.main()
