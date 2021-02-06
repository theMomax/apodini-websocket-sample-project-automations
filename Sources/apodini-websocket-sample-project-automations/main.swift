
import Apodini
import ApodiniWebSocket
import ApodiniOpenAPI
import ApodiniREST

struct AutomationService: Apodini.WebService {
    var configuration: Configuration {
        AutomationStoreConfiguration()
        ExporterConfiguration()
            .exporter(WebSocketInterfaceExporter.self)
            .exporter(OpenAPIInterfaceExporter.self)
            .exporter(RESTInterfaceExporter.self)
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
