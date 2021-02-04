
import Apodini
import AsyncHTTPClient

struct AutomationService: Apodini.WebService {
    var configuration: Configuration {
        AutomationStoreConfiguration()
    }
    
    var content: some Component {
        Group("channel") {
            ChannelHandler()
        }
        Group("automation") {
            AutomationRegistrationHandler().operation(.create)
        }
        Group("device") {
            DeviceRegistrationHandler()
        }
    }
}

try AutomationService.main()
