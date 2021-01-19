
import Apodini

struct AutomationService: Apodini.WebService {
    
    var content: some Component {
        Group("channel") {
            ChannelReceptionHandler()
        }
        Group("automation") {
            AutomationRegistrationHandler()
        }
    }
}

try AutomationService.main()
