

//@MainActor
//class UserClient: ObservableObject {
//    static let shared = UserClient()
//    
//    @Published var username: String = ""
//    @Published var messages: [String] = []
//    @Published var dmUsers: [String] = [] // For DMs tab
//    @Published var topics: [String] = []  // For Topics tab
//    
//    private var connection: NWConnection?
//    
//    private init() {}
//    
//    func login(username: String) async -> Bool {
//        self.username = username
//        connect()
//        send("CREATE_USER:\(username)")
//        
//        // Wait briefly to receive broker confirmation
//        try? await Task.sleep(nanoseconds: 300_000_000)
//        
//        if let last = messages.last, last.contains("Duplicate username") {
//            return false
//        }
//        return true
//    }
//    
//    private func connect() {
//        connection = NWConnection(host: "localhost", port: 8080, using: .tcp)
//        connection?.start(queue: .global())
//        listen()
//    }
//    
//    private func listen() {
//        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, _ in
//            if let data = data, let msg = String(data: data, encoding: .utf8) {
//                DispatchQueue.main.async {
//                    self.messages.append(msg)
//                    
//                    // Auto-update DM list if new DM is received
//                    if msg.contains("[DM from") {
//                        if let sender = msg.components(separatedBy: " ").dropFirst(2).first {
//                            if !self.dmUsers.contains(sender) {
//                                self.dmUsers.append(sender)
//                            }
//                        }
//                    }
//                }
//            }
//            Task { @MainActor in
//                self.listen()
//            }
//        }
//    }
//    
//    func send(_ message: String) {
//        connection?.send(content: message.data(using: .utf8), completion: .contentProcessed { _ in })
//    }
//    
//    func sendDM(to user: String, content: String) {
//        send("MSG:\(username):\(user):\(content)")
//        if !dmUsers.contains(user) {
//            dmUsers.append(user)
//            messages.append("You added \(user)")
//        }
//    }
//    
//    func sendTopicMessage(to topic: String, content: String) {
//        send("TOPIC_MSG:\(username):\(topic):\(content)")
//    }
//    
//    func subscribe(to topic: String) {
//        send("SUBSCRIBE:\(username):\(topic)")
//        if !topics.contains(topic) {
//            topics.append(topic)
//            messages.append("\(username) entered topic \(topic)")
//        }
//    }
//}

import Network
import SwiftUI

@MainActor
class UserClient: ObservableObject {
    static let shared = UserClient()
    
    @Published var username: String = ""
    @Published var messages: [Message] = []
    @Published var dmUsers: [String: Bool] = [:]
    @Published var topics: [String] = []
    @Published var typingIndicators: Set<String> = []
    @Published var loginStatus: String? = nil // ✅ Track login response

    private var connection: NWConnection?

    func login(username: String, isNew: Bool) async -> Bool {
        self.username = username
        connect()
        if isNew { send("CREATE_USER:\(username)") }
        else { send("LOGIN_USER:\(username)") }
        
        let start = Date()
        while loginStatus == nil && Date().timeIntervalSince(start) < 2 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        if let status = loginStatus, status.starts(with: "LOGIN_OK") {
            if status.contains("EXISTING:") {
                let payload = status.replacingOccurrences(of: "LOGIN_OK:EXISTING:", with: "")
                let parts = payload.split(separator: "|")
                if parts.count > 0 { self.topics = parts[0].isEmpty ? [] : parts[0].split(separator: ",").map(String.init) }
                if parts.count > 1 {
                    let dms = parts[1].isEmpty ? [] : parts[1].split(separator: ",").map(String.init)
                    for dm in dms { self.dmUsers[dm] = false }
                }
            }
            if status.starts(with: "LOGIN_OK:EXISTING:") {
                let jsonString = status.replacingOccurrences(of: "LOGIN_OK:EXISTING:", with: "")
                if let data = jsonString.data(using: .utf8),
                   let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                    self.topics = payload["topics"] as? [String] ?? []
                    let dms = payload["dms"] as? [String] ?? []
                    dms.forEach { self.dmUsers[$0] = false }

                    if let dmHist = payload["dmHistory"] as? [String: [String]] {
                        for (_, msgs) in dmHist {
                            for msg in msgs { self.appendParsedDM(msg) }
                        }
                    }

                    if let topicHist = payload["topicHistory"] as? [String: [String]] {
                        for (_, msgs) in topicHist {
                            for msg in msgs { self.appendParsedTopic(msg) }
                        }
                    }
                }
            }
            loginStatus = nil
            return true
        }
        loginStatus = nil
        return false
    }

    private func connect() {
        connection = NWConnection(host: "localhost", port: 8080, using: .tcp)
        connection?.start(queue: .global())
        listen()
    }

    private func listen() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, _ in
            if let data = data, let msg = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { self.handleIncoming(msg) }
            }
            Task { @MainActor in
                self.listen()
            }
        }
    }

    private func handleIncoming(_ raw: String) {
        if raw == "PING" {
            send("PONG:\(username)")
            return
        }
        if raw.starts(with: "STATUS:") {
            let parts = raw.split(separator: ":")
            if parts.count == 3 {
                let user = String(parts[1])
                let online = parts[2] == "ONLINE"
                dmUsers[user] = online
            }
            return
        }
        if raw.starts(with: "LOGIN_OK") || raw.starts(with: "LOGIN_FAIL") {
            loginStatus = raw // ✅ Capture login response directly
        }
        else if raw.starts(with: "STATUS:") {
            let parts = raw.split(separator: ":")
            if parts.count == 3 {
                let user = String(parts[1])
                dmUsers[user] = parts[2] == "ONLINE"
            }
        }
        else if raw.starts(with: "TYPING_INDICATOR:") {
            let sender = raw.replacingOccurrences(of: "TYPING_INDICATOR:", with: "")
            typingIndicators.insert(sender)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.typingIndicators.remove(sender) }
        }
        else if raw.starts(with: "SENT:") {
            let msg = raw.replacingOccurrences(of: "SENT:", with: "")
            updateMessageDelivery(msg: msg, delivered: false)
        }
        else if raw.starts(with: "DELIVERED:") {
            let msg = raw.replacingOccurrences(of: "DELIVERED:", with: "")
            updateMessageDelivery(msg: msg, delivered: true)
        }
        else if raw.starts(with: "[DM from") {
            // Parse: "[DM from Alice] Hello @10:00"
            let components = raw.components(separatedBy: "] ")
            if components.count == 2 {
                let header = components[0] // "[DM from Alice"
                let body = components[1]   // "Hello @10:00"
                let sender = header.replacingOccurrences(of: "[DM from ", with: "")
                
                messages.append(Message(
                    sender: sender,
                    text: body,   // ✅ Store clean text, no brackets
                    timestamp: Date(),
                    delivered: true
                ))
            }
        } else if raw.starts(with: "[Topic") {
            // Example raw: "[Topic Swift from Alice] Hello!"
            let headerSplit = raw.components(separatedBy: "] ")
            if headerSplit.count == 2 {
                let header = headerSplit[0] // "[Topic Swift from Alice"
                let body = headerSplit[1]   // "Hello!"

                let parts = header.replacingOccurrences(of: "[Topic ", with: "")
                    .components(separatedBy: " from ")

                if parts.count == 2 {
                    let topicName = parts[0]
                    let sender = parts[1]
                    messages.append(Message(sender: sender, text: "[\(topicName)] \(body)", timestamp: Date(), delivered: true))
                }
            }
        }

    }
    
    func sendDM(to user: String, content: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        send("MSG:\(username):\(user):\(timestamp):\(content)")
        messages.append(Message(sender: username, text: content, timestamp: Date(), delivered: false))
        
        if dmUsers[user] == nil {  // ✅ Add them with default offline if new
            dmUsers[user] = false
        }
    }
    
    func sendTyping(to user: String) {
        send("TYPING:\(username):\(user)")
    }
    
    func sendTopicMessage(to topic: String, content: String) {
        send("TOPIC_MSG:\(username):\(topic):\(content)")
    }
    
    func subscribe(to topic: String) {
        send("SUBSCRIBE:\(username):\(topic)")
        if !topics.contains(topic) {
            topics.append(topic)
            messages
                .append(
                    Message(sender: username,
                            text: "\(username) entered topic \(topic)",
                            timestamp: .now,
                            delivered: true)
//                    "\(username) entered topic \(topic)"
                )
        }
    }
    
    private func updateMessageDelivery(msg: String, delivered: Bool) {
        if let index = messages.firstIndex(where: { $0.text == msg }) {
            messages[index].delivered = delivered
        }
    }
    
    private func parseSender(from raw: String) -> String {
        if raw.contains("[DM from") {
            return raw.components(separatedBy: " ")[2]
        } else { return "System" }
    }
    
    func send(_ message: String) {
        connection?.send(content: message.data(using: .utf8), completion: .contentProcessed { _ in })
    }
    
    func appendParsedDM(_ raw: String) {
        let components = raw.components(separatedBy: "] ")
        if components.count == 2 {
            let sender = components[0].replacingOccurrences(of: "[DM from ", with: "")
            let body = components[1]
            messages.append(Message(sender: sender, text: body, timestamp: Date(), delivered: true))
        }
    }

    func appendParsedTopic(_ raw: String) {
        let components = raw.components(separatedBy: "] ")
        if components.count == 2 {
            let header = components[0] // "[Topic topicName from Alice"
            let parts = header.components(separatedBy: " from ")
            let sender = parts.last ?? "System"
            let body = components[1]
            messages.append(Message(sender: sender, text: body, timestamp: Date(), delivered: true))
        }
    }

}

struct Message: Identifiable {
    let id = UUID()
    let sender: String
    var text: String
    var timestamp: Date
    var delivered: Bool
}
