//
//  Client.swift
//
//
//  Created by Max Obermeier on 05.01.21.
//

import Foundation
import Vapor
import Logging
import OpenCombine

/// A stateless client-implementation to `VaporWSRouter`. It cannot react to responses
/// from the server but only collect them for the caller.
public struct StatelessClient {
    private let address: String
    
    private let logger: Logger
    
    private let eventLoop: EventLoop
    
    private let ignoreErrors: Bool
    
    /// Create a `StatelessClient` that will connect to the given `address` once used. All operations
    /// are executed on the given `eventLoop`.
    public init(address: String = "ws://localhost:8080/apodini/websocket", on eventLoop: EventLoop, ignoreErrors: Bool = false) {
        self.address = address
        var logger = Logger(label: "org.apodini.websocket.client")
        #if DEBUG
        logger.logLevel = .debug
        #endif
        self.logger = logger
        self.eventLoop = eventLoop
        self.ignoreErrors = ignoreErrors
    }
    
    /// Opens a new WebSocket connection, creates a new context on the given `endpoint` and sends
    /// one client-message carrying `input`. Afterwards it sends a close-context-message. The future
    /// completes when the client receives a close-content-message from the server. The future contains
    /// the first server-message received on the relevant context. If so server-message was received, the
    /// future fails.
    public func resolve<I: Encodable, O: Decodable>(one input: I, on endpoint: String) -> EventLoopFuture<O> {
        self.resolve(input, on: endpoint).flatMapThrowing { (response: [O]) in
            guard let first = response.first else {
                throw ServerError.noMessage
            }
            return first
        }
    }
    
    /// Opens a new WebSocket connection, creates a new context on the given `endpoint` and sends
    /// one client message for each element in `input`. Afterwards it sends a close-context-message. The future
    /// completes when the client receives a close-content-message from the server. The future contains
    /// all server-messages received on the relevant context.
    public func resolve<I: Encodable, O: Decodable>(_ inputs: I..., on endpoint: String) -> EventLoopFuture<[O]> {
        resolve(many: inputs, on: endpoint)
    }
    
    /// Opens a new WebSocket connection, creates a new context on the given `endpoint` and sends
    /// one client message for each element in `input`. Afterwards it sends a close-context-message. The future
    /// completes when the client receives a close-content-message from the server. The future contains
    /// all server-messages received on the relevant context.
    public func resolve<I: Encodable, O: Decodable>(many inputs: [I], on endpoint: String) -> EventLoopFuture<[O]> {
        let promise = eventLoop.makePromise(of: [O].self)
        var cancellables = Set<AnyCancellable>()
        resolve(from: inputs.publisher, on: endpoint).collect().sink(receiveCompletion: { completion in
            switch completion {
            case .failure(let error):
                promise.fail(error)
            default:
                break
            }
            cancellables.removeAll()
        }, receiveValue: { value in
            promise.succeed(value)
        }).store(in: &cancellables)
        
        return promise.futureResult
    }
    
    public func resolve<I: Publisher, O: Decodable>(_ type: O.Type = O.self, from publisher: I, on endpoint: String) -> AnyPublisher<O, Error> where I.Failure == Never, I.Output: Encodable {
        let output = PassthroughSubject<O, Error>()
        
        let publisher = publisher.buffer()
        
        var cancellables = Set<AnyCancellable>()
        
        _ = WebSocket.connect(
            to: self.address,
            on: eventLoop
        ) { websocket in
            let contextId = UUID()
            let contextPromise = eventLoop.makePromise(of: Void.self)
            self.sendOpen(context: contextId, on: endpoint, to: websocket, promise: contextPromise)

            contextPromise.futureResult.whenComplete { result in
                switch result {
                case .failure(let error):
                    output.send(completion: .failure(error))
                    // close connection
                    _ = websocket.close()
                case .success:
                    self.send(messagePublisher: publisher, on: contextId, to: websocket, output: output, cancellables: &cancellables)
                }
            }

            websocket.onText { websocket, string in
                self.onText(
                    websocket: websocket,
                    string: string,
                    context: contextId,
                    output: output
                )
            }

            websocket.onClose.whenComplete { _ in
                output.send(completion: .finished)
                cancellables.removeAll()
            }
        }
        
        return output.eraseToAnyPublisher()
    }
    
    private func sendOpen(context: UUID, on endpoint: String, to websocket: WebSocket, promise: EventLoopPromise<Void>) {
        do {
            // create context on user endpoint
            let message = try encode(OpenContextMessage(context: context, endpoint: endpoint))
            self.logger.debug(">>> \(message)")
            websocket.send(message, promise: promise)
        } catch {
            promise.fail(error)
        }
    }
    
    private func send<P: Publisher, O>(messagePublisher: P, on context: UUID, to websocket: WebSocket, output: PassthroughSubject<O, Error>, cancellables: inout Set<AnyCancellable>) where P.Failure == Never, P.Output: Encodable {        
        messagePublisher.sink(receiveCompletion: { _ in
            self.sendClose(context: context, to: websocket, output: output)
        }, receiveValue: { input in
            do {
                let message = try encode(ClientMessage(context: context, parameters: input))
                self.logger.debug(">>> \(message)")
                // create context on user endpoint
                websocket.send(message)
            } catch {
                output.send(completion: .failure(error))
                // close connection
                _ = websocket.close()
            }
        }).store(in: &cancellables)
    }
    
    private func sendClose<O>(context: UUID, to websocket: WebSocket, output: PassthroughSubject<O, Error>) {
        do {
            let message = try encode(CloseContextMessage(context: context))
            self.logger.debug(">>> \(message)")
            // announce end of client-messages
            websocket.send(message)
        } catch {
            output.send(completion: .failure(error))
            // close connection
            _ = websocket.close()
        }
    }
    
    private func onText<O: Decodable>(
        websocket: WebSocket,
        string: String,
        context: UUID,
        output: PassthroughSubject<O, Error>
    ) {
        self.logger.debug("<<< \(string)")
        
        guard let data = string.data(using: .utf8) else {
            output.send(completion: .failure(ConversionError.couldNotDecodeUsingUTF8))
            // close connection
            _ = websocket.close()
            return
        }

        do {
            let result = try JSONDecoder().decode(ServiceMessage<O>.self, from: data)
            if result.context == context {
                output.send(result.content)
            }
        } catch {
            do {
                let result = try JSONDecoder().decode(ErrorMessage<String>.self, from: data)
                if (result.context == context || result.context == nil) && !self.ignoreErrors {
                    output.send(completion: .failure(ServerError.message(result.error)))
                    // close connection
                    _ = websocket.close()
                    return
                }
            } catch {
                do {
                    let result = try JSONDecoder().decode(CloseContextMessage.self, from: data)
                    if result.context == context {
                        // close connection
                        _ = websocket.close()
                    }
                } catch { }
            }
        }
    }
}

private class MockCancellable {
    
}

private enum ServerError: Error {
    case message(String)
    case noMessage
}

private enum ConversionError: String, Error {
    case couldNotEncodeUsingUTF8
    case couldNotDecodeUsingUTF8
}

private func encode<M: Encodable>(_ message: M) throws -> String {
    let data = try JSONEncoder().encode(message)
    
    guard let stringMessage = String(data: data, encoding: String.Encoding.utf8) else {
        throw ConversionError.couldNotEncodeUsingUTF8
    }
    
    return stringMessage
}


// MARK: Message Types

struct OpenContextMessage: Encodable {
    var context: UUID
    var endpoint: String
    
    init(context: UUID, endpoint: String) {
        self.context = context
        self.endpoint = endpoint
    }
}

struct CloseContextMessage: Codable {
    var context: UUID
    
    init(context: UUID) {
        self.context = context
    }
}

struct ClientMessage<I: Encodable>: Encodable {
    var context: UUID
    var parameters: I
}

private struct EncodableServiceMessage<C: Encodable>: Encodable {
    var context: UUID
    var content: C
}

struct ServiceMessage<C: Decodable>: Decodable {
    var context: UUID
    var content: C
}

struct ErrorMessage<E: Codable>: Codable {
    var context: UUID?
    var error: E
}
