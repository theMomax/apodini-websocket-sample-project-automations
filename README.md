# Apodini WebSocket - Home Hub PoC

This is an example project displaying how one could go about implementing a **Home Hub** for automating your smart home using [Apodini](https://github.com/Apodini/Apodini) - a declarative, composable Server-Side Swift framework.

The focus of this example project is the usage of WebSocket-based bidirectional channels for communication between Hub and Device.

## Getting Started

1. Start the Hub by running the `apodini-websocket-sample-project-automations` target.
2. Explore the Hub's endpoints using its [SwaggerUI](http://localhost:8080/openapi-ui).
<br>The only endpoint you as a User will use is `/v1/automation` where you can add *Automations*.
2. Start the server hosting the mock-devices by running the `apodini-websocket-sample-project-automations-client` target.
3. Explore the Devices' endpoints using the mock-device-server's [SwaggerUI](http://localhost:7001/openapi-ui).
<br>You can use the `/v1/<DEVICE>/update/<CHANNEL>` endpoint to manually update the value of a Device's Channel.
<br>You can use the `/v1/<DEVICE>/retrieve/<CHANNEL>` endpoint to get the current value of a Device's Channel.
4. Add two Automations: `motiondetector:triggered == 1 --> lamp:on = 1` and motiondetector:triggered == 0 --> lamp:on = 0 either using the Hub's SwaggerUI or using curl, e.g.: `curl -X POST "http://127.0.0.1:8080/v1/automation?automation=motiondetector%3Atriggered%20%3D%3D%200%20--%3E%20lamp%3Aon%20%3D%200" -H  "accept: application/json" -d ""`
5. Manually update the `motiondetector`'s `triggered` Channel. Again, you can either use the client-server's SwaggerUI or curl: `curl -X GET "http://localhost:7001/v1/motiondetector/update/triggered?value=1" -H  "accept: application/json"`. You should now see an image of a powered-on lightbulb popping up. Once you change the `triggered` Channel's value back to `1` the light turns off again.


## Mock Devices

You can define which Devices are hosted by the client-server at `Sources/apodini-websocket-sample-project-automations-client/main.swift`. You can see how these devices are implemented at `Sources/apodini-websocket-sample-project-automations-client/Device.swift`.

The following devices are hosted by default:

* Device `motiondetector`
    * Channel `triggered`
* Device `lamp`
    * Channel `on`
* Device `outlet`
    * Channel `on`
    * Channel `power`

## Limitations of this Proof of Concept

* For simplicity all Channel's values are of type `Double`
* The whole process of de-registering Devices or Automations is not implemented