import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Combine)
import Combine
#endif

enum WebSocketState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

#if canImport(Combine)
protocol WebSocketClientObserving: ObservableObject {}
#else
protocol WebSocketClientObserving {}
#endif

#if canImport(UIKit)
final class WebSocketClient: NSObject, WebSocketClientObserving {
#if canImport(Combine)
    @Published private(set) var state: WebSocketState = .disconnected
    @Published var lastError: String?
#else
    private(set) var state: WebSocketState = .disconnected
    var lastError: String?
#endif
    private let endpoints: ServerEndpoints
    private let keychain: KeychainStore
    private let session: URLSession
    private var socket: URLSessionWebSocketTask?
    private var reconnectTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var generation = 0
    private var reconnectDelay: TimeInterval = 1
    var eventHandler: ((WebSocketEvent) -> Void)?

    init(endpoints: ServerEndpoints, keychain: KeychainStore = KeychainStore(), session: URLSession = .shared) {
        self.endpoints = endpoints
        self.keychain = keychain
        self.session = session
        super.init()
    }

    func connect() {
        guard let token = try? keychain.current()?.tokens.accessToken, !token.isEmpty else { return }
        disconnect(immediate: true)
        let currentGeneration = generation
        var request = URLRequest(url: endpoints.websocket)
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let task = session.webSocketTask(with: request)
        socket = task
        state = .connecting
        task.resume()
        receive(on: task, generation: currentGeneration)
        schedulePing(task: task, generation: currentGeneration)
    }

    func disconnect(immediate: Bool = false) {
        generation += 1
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        socket?.cancel()
        socket = nil
        if immediate { state = .disconnected }
    }

    func sendChat(recipientID: Int, content: String, clientMessageID: String) {
        send([
            "type": "chat.send" as Any,
            "recipientId": recipientID,
            "content": content,
            "clientMessageId": clientMessageID
        ])
    }

    func sendRead(messageID: Int) {
        send(["type": "chat.read" as Any, "messageId": messageID])
    }

    func sendTransferStatus(transferID: String) {
        send(["type": "transfer.status" as Any, "transferId": transferID])
    }

    func ping() {
        send(["type": "ping" as Any, "data": NSNull()])
    }

    private func send(_ payload: [String: Any]) {
        guard state == .connected, let socket else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        socket.send(.data(data)) { error in
            if let error { Task { @MainActor in self.lastError = error.localizedDescription } }
        }
    }

    private func receive(on task: URLSessionWebSocketTask, generation: Int) {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            guard let self else { return }
            while generation == self.generation, task.state == .running {
                do {
                    let message = try await task.receive()
                    switch message {
                    case let .string(text):
                        self.handle(raw: text, generation: generation)
                    case let .data(data):
                        if let text = String(data: data, encoding: .utf8) { self.handle(raw: text, generation: generation) }
                    @unknown default: break
                    }
                } catch is CancellationError {
                    return
                } catch {
                    if generation == self.generation {
                        Task { @MainActor in
                            self.lastError = error.localizedDescription
                            self.scheduleReconnect()
                        }
                    }
                    return
                }
            }
        }
    }

    private func handle(raw: String, generation: Int) {
        guard let data = raw.data(using: .utf8), let event = try? JSONDecoder().decode(WebSocketEvent.self, from: data) else { return }
        Task { @MainActor in
            if generation == self.generation {
                switch event.type {
                case "connected": self.state = .connected
                case "error": self.lastError = event.error?.message
                default: break
                }
            }
        }
        eventHandler?(event)
    }

    private func schedulePing(task: URLSessionWebSocketTask, generation: Int) {
        Task { [weak self] in
            guard let self else { return }
            while generation == self.generation, task.state == .running {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                if generation == self.generation, task.state == .running { task.sendPing { error in
                    if error != nil, generation == self.generation { Task { @MainActor in self.scheduleReconnect() } }
                } }
            }
        }
    }

    private func scheduleReconnect() {
        guard state != .reconnecting else { return }
        state = .reconnecting
        let reconnectGeneration = generation
        let delay = reconnectDelay
        reconnectDelay = min(30, reconnectDelay * 2)
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if self.generation == reconnectGeneration {
                self.reconnectDelay = 1
                self.connect()
            }
        }
    }
}
#else
final class WebSocketClient: NSObject {
    private(set) var state: WebSocketState = .disconnected
    var lastError: String?
    var eventHandler: ((WebSocketEvent) -> Void)?

    init(endpoints: ServerEndpoints, keychain: KeychainStore = KeychainStore(), session: URLSession = .shared) {}

    func connect() {}
    func disconnect(immediate: Bool = false) { state = .disconnected }
    func sendChat(recipientID: Int, content: String, clientMessageID: String) {}
    func sendRead(messageID: Int) {}
    func sendTransferStatus(transferID: String) {}
    func ping() {}
}
#endif
