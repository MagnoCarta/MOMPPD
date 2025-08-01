import Network
import Foundation

class BrokerServer {
    var listener: NWListener!
    var connections: [String: NWConnection] = [:]
    var manager = BrokerManager()
    var logHandler: ((String) -> Void)?
    var lastSeen: [String: Date] = [:]
    
    private let heartbeatQueue = DispatchQueue(label: "broker.heartbeat.queue", qos: .background)
    
    init(logHandler: ((String) -> Void)? = nil) {
        self.logHandler = logHandler
    }
    
    func start() {
        manager.loadState()
        listener = try! NWListener(using: .tcp, on: 8080)
        listener.newConnectionHandler = { conn in
            conn.start(queue: .global())
            self.handleNewConnection(conn)
        }
        listener.start(queue: .global())
        log("✅ Broker running on port 8080")

        heartbeatQueue.async { [weak self] in
            self?.setupHeartbeatTimer()
            RunLoop.current.run() // Keep the heartbeat loop alive
        }
    }
    
    private func sendHeartbeats() {
        let now = Date()
        for (username, conn) in connections {
            // Send PING on a concurrent background thread
            DispatchQueue.global(qos: .background).async {
                self.send("PING", to: conn)
            }
            
            // Check last seen timestamps
            if let last = lastSeen[username], now.timeIntervalSince(last) > 10 {
                self.log("⚠️ No heartbeat from \(username). Disconnecting.")
                self.cleanupConnection(conn)
            }
        }
    }
    
    private func setupHeartbeatTimer() {
        let timer = DispatchSource.makeTimerSource(queue: heartbeatQueue)
        timer.schedule(deadline: .now(), repeating: 5.0)
        timer.setEventHandler { [weak self] in
            self?.sendHeartbeats()
        }
        timer.resume()
    }


    private func cleanupConnection(_ conn: NWConnection) {
        if let (username, _) = connections.first(where: { $0.value === conn }) {
            self.log("❌ Cleaning up connection for user: \(username)")
            connections.removeValue(forKey: username)
            userStatus[username] = false
            broadcastUserStatus(username, isOnline: false)
            conn.cancel()
        }
    }
    
    func handleNewConnection(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            if let error = error {
                self.log("⚠️ Connection error: \(error)")
                self.cleanupConnection(conn)
                return
            }
            
            if isComplete {
                self.log("🔌 Connection closed by client.")
                self.cleanupConnection(conn)
                return
            }
            
            if let data = data, !data.isEmpty, let message = String(data: data, encoding: .utf8) {
                self.handleCommand(message, from: conn)
                self.handleNewConnection(conn) // ✅ Continue reading only if active
            } else {
                self.handleNewConnection(conn) // No data but still alive
            }
        }
    }

    
    private func reconnectUserIfNeeded(_ username: String, _ conn: NWConnection) {
        if connections[username] == nil {
            connections[username] = conn
            log("🔌 Auto-reconnected user: \(username)")
        }
    }
    
    
    // Add user connection state tracking
    var userStatus: [String: Bool] = [:] // true = online, false = offline

    func handleCommand(_ command: String, from conn: NWConnection) {
        if command.starts(with: "PONG:") {
            let username = command.replacingOccurrences(of: "PONG:", with: "")
            lastSeen[username] = Date()
            return
        }
        if command.starts(with: "CREATE_USER:") {
            let username = command.replacingOccurrences(of: "CREATE_USER:", with: "")
            if manager.createUser(username) {
                connections[username] = conn
                userStatus[username] = true
                send("LOGIN_OK:NEW", to: conn)
                manager.saveState()
                log("👤 User created: \(username)")
                broadcastUserStatus(username, isOnline: true)
            } else {
                send("LOGIN_FAIL", to: conn)
            }
        }
        else if command.starts(with: "LOGIN_USER:") {
            let username = command.replacingOccurrences(of: "LOGIN_USER:", with: "")
            if manager.users.keys.contains(username) {
                connections[username] = conn
                userStatus[username] = true
                deliverOfflineMessages(to: username, conn: conn)
                
                let topics = manager.topics.filter { $0.subscribers.contains(username) }.map { $0.name }
                let dms = manager.dmContacts[username] ?? []
                let dmHistory = manager.getDMHistory(for: username)
                let topicHistory = topics.reduce(into: [String: [String]]()) { dict, topic in
                    dict[topic] = manager.topicHistory[topic] ?? []
                }

                // Serialize history payload as JSON
                let historyPayload: [String: Any] = [
                    "topics": topics,
                    "dms": dms,
                    "dmHistory": dmHistory,
                    "topicHistory": topicHistory
                ]
                if let json = try? JSONSerialization.data(withJSONObject: historyPayload),
                   let jsonString = String(data: json, encoding: .utf8) {
                    send("LOGIN_OK:EXISTING:\(jsonString)", to: conn)
                }

                manager.saveState()
                broadcastUserStatus(username, isOnline: true)
            } else {
                send("LOGIN_FAIL", to: conn)
            }
        }
        else if command.starts(with: "TYPING:") {
            // Notify the recipient that user is typing
            let parts = command.replacingOccurrences(of: "TYPING:", with: "").split(separator: ":")
            if parts.count == 2 {
                let sender = String(parts[0])
                let target = String(parts[1])
                if let targetConn = connections[target] {
                    send("TYPING_INDICATOR:\(sender)", to: targetConn)
                }
            }
        }
        else if command.starts(with: "MSG:") {
            let parts = command.replacingOccurrences(of: "MSG:", with: "").split(separator: ":", maxSplits: 3)
            if parts.count == 4 {
                let sender = String(parts[0])
                let recipient = String(parts[1])
                let timestamp = String(parts[2])
                let msg = String(parts[3])
                let formatted = "[DM from \(sender)] \(msg) @\(timestamp)"

                // Add both as contacts
                manager.addDMContact(for: sender, contact: recipient)
                manager.addDMContact(for: recipient, contact: sender)
                manager.addDMMessage(sender: sender,
                                     recipient: recipient,
                                     message: formatted)

                // Deliver or queue offline
                if let conn = connections[recipient] {
                    log("📨 Sending DM to \(recipient): \(formatted)")
                    send("DELIVERED:\(msg)", to: connections[sender]!)
                    send(formatted, to: conn)
                } else {
                    log("⚠️ Recipient \(recipient) not connected. Queuing offline.")
                    manager.queueOfflineMessage(for: recipient, message: formatted)
                    send("SENT:\(msg)", to: connections[sender]!)
                }
                manager.saveState()
            }
        } else if command.starts(with: "TOPIC_MSG:") {
            let parts = command.replacingOccurrences(of: "TOPIC_MSG:", with: "").split(separator: ":", maxSplits: 2)
            if parts.count == 3 {
                let sender = String(parts[0])
                let topicName = String(parts[1])
                let msg = String(parts[2])
                
                manager.subscribeUser(username: sender, to: topicName) // Ensure user is subscribed
                if let topic = manager.topics.first(where: { $0.name == topicName }) {
                    for user in topic.subscribers {
                        if let conn = connections[user] {
                            manager.addTopicMessage(topic: topicName, message: "[Topic \(topicName) from \(sender)] \(msg)")
                            send("[Topic \(topicName) from \(sender)] \(msg)", to: conn)
                        } else {
                            manager.queueOfflineMessage(for: user, message: "[Topic \(topicName) from \(sender)] \(msg)")
                        }
                    }
                    manager.saveState()
                }
            }
        }
        else if command.starts(with: "SUBSCRIBE:") {
            let parts = command.split(separator: ":")
            if parts.count == 3 {
                let username = String(parts[1])
                let topicName = String(parts[2])
                manager.subscribeUser(username: username, to: topicName)
                manager.saveState()

                // Send confirmation back
                send("SUBSCRIBED:\(topicName)", to: conn)

                // ✅ Notify broker GUI through log handler
                logHandler?("🔔 \(username) subscribed to topic \(topicName)")
            }
        }


    }

    // Broadcast user online/offline status to DM contacts
    func broadcastUserStatus(_ username: String, isOnline: Bool) {
        for (user, conn) in connections {
            if user != username {
                send("STATUS:\(username):\(isOnline ? "ONLINE" : "OFFLINE")", to: conn)
            }
        }
    }

    func disconnectUser(_ username: String) {
        connections.removeValue(forKey: username)
        userStatus[username] = false
        broadcastUserStatus(username, isOnline: false)
    }

    
    private func deliverOfflineMessages(to user: String, conn: NWConnection) {
        if let offline = manager.getOfflineMessages(for: user) {
            for msg in offline { send("[OFFLINE MSG] \(msg)", to: conn) }
            manager.clearOfflineMessages(for: user)
        }
    }
    
    func send(_ message: String, to conn: NWConnection) {
        conn.send(content: message.data(using: .utf8), completion: .contentProcessed { _ in })
    }
    
    private func log(_ text: String) {
        logHandler?(text)
        print(text)
    }
}


// MARK: - Models
struct BrokerState: Codable {
    var queues: [Queue]
    var topics: [Topic]
    var users: [String]
    var offlineMessages: [String: [String]]
    var dmContacts: [String: [String]]
    var dmHistory: [String: [String]]    // ✅ user-pair key: "Alice|Bob" → messages
    var topicHistory: [String: [String]] // ✅ topic name → messages
}


class Queue: Codable {
    var name: String
    var messages: [String] = []
    init(name: String) { self.name = name }
}

class Topic: Codable {
    var name: String
    var subscribers: [String] = []
    init(name: String) { self.name = name }
}

// MARK: - Broker Manager with Persistence
//class BrokerManager {
//    var queues: [Queue] = []
//    var topics: [Topic] = []
//    var users: [String: Queue] = [:]
//    var offlineMessages: [String: [String]] = [:]
//    
//    private let storageFile = "brokerData.json"
//    
//    func addQueue(_ name: String) { queues.append(Queue(name: name)) }
//    func listQueues() -> [String] { queues.map { "\($0.name) (\($0.messages.count) msgs)" } }
//    func addTopic(_ name: String) { topics.append(Topic(name: name)) }
//    func listTopics() -> [String] { topics.map { $0.name } }
//    
//    func createUser(_ name: String) -> Bool {
//        guard users[name] == nil else { return false }
//        let q = Queue(name: "queue_\(name)")
//        users[name] = q
//        queues.append(q)
//        return true
//    }
//    
//    func subscribeUser(username: String, to topicName: String) {
//        if let topic = topics.first(where: { $0.name == topicName }) {
//            if !topic.subscribers.contains(username) {
//                topic.subscribers.append(username)
//            }
//        } else {
//            addTopic(topicName)
//            subscribeUser(username: username, to: topicName)
//        }
//    }
//    
//    func unsubscribeUser(username: String, from topicName: String) {
//        if let topic = topics.first(where: { $0.name == topicName }) {
//            topic.subscribers.removeAll { $0 == username }
//        }
//    }
//    
//    func getSubscribers(of topicName: String) -> [String] {
//        return topics.first(where: { $0.name == topicName })?.subscribers ?? []
//    }
//    
//    func queueOfflineMessage(for user: String, message: String) {
//        offlineMessages[user, default: []].append(message)
//    }
//
//    func getOfflineMessages(for user: String) -> [String]? {
//        return offlineMessages[user]
//    }
//
//    func clearOfflineMessages(for user: String) {
//        offlineMessages[user] = []
//    }
//
//    // MARK: Persistence
//    func saveState() {
//        let state = BrokerState(
//            queues: queues,
//            topics: topics,
//            users: Array(users.keys),
//            offlineMessages: offlineMessages
//        )
//        if let data = try? JSONEncoder().encode(state) {
//            try? data.write(to: URL(fileURLWithPath: storageFile))
//        }
//    }
//    
//    func loadState() {
//        let url = URL(fileURLWithPath: storageFile)
//        guard let data = try? Data(contentsOf: url),
//              let state = try? JSONDecoder().decode(BrokerState.self, from: data) else { return }
//        
//        self.queues = state.queues
//        self.topics = state.topics
//        self.users = Dictionary(uniqueKeysWithValues: state.users.map { ($0, Queue(name: "queue_\($0)")) })
//        self.offlineMessages = state.offlineMessages
//        print("✅ Loaded broker state with \(users.count) users, \(queues.count) queues, and \(topics.count) topics.")
//    }
//}

class BrokerManager {
    var queues: [Queue] = []
    var topics: [Topic] = []
    var users: [String: Queue] = [:]
    var offlineMessages: [String: [String]] = [:]
    var dmContacts: [String: [String]] = [:]   // ✅ Track DM contacts per user
    
    private let storageFile = "brokerData.json"
    
    func addQueue(_ name: String) { queues.append(Queue(name: name)) }
    func addTopic(_ name: String) { if topics.first(where: { $0.name == name }) == nil { topics.append(Topic(name: name)) } }
    
    func createUser(_ name: String) -> Bool {
        guard users[name] == nil else { return false }
        let q = Queue(name: "queue_\(name)")
        users[name] = q
        queues.append(q)
        dmContacts[name] = []   // Initialize empty contact list
        return true
    }
    
    func subscribeUser(username: String, to topicName: String) {
        if topics.first(where: { $0.name == topicName }) == nil {
            addTopic(topicName)
        }
        if let topic = topics.first(where: { $0.name == topicName }) {
            if !topic.subscribers.contains(username) {
                topic.subscribers.append(username)
            }
        }
    }
    
    func unsubscribeUser(username: String, from topicName: String) {
        if let topic = topics.first(where: { $0.name == topicName }) {
            topic.subscribers.removeAll { $0 == username }
        }
    }
    
    func addDMContact(for user: String, contact: String) {
        var contacts = dmContacts[user] ?? []
        if !contacts.contains(contact) {
            contacts.append(contact)
            dmContacts[user] = contacts
        }
    }
    
    func saveState() {
        let state = BrokerState(
            queues: queues,
            topics: topics,
            users: Array(users.keys),
            offlineMessages: offlineMessages,
            dmContacts: dmContacts,
            dmHistory: dmHistory,
            topicHistory: topicHistory
        )
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: URL(fileURLWithPath: storageFile))
        }
    }

    func loadState() {
        let url = URL(fileURLWithPath: storageFile)
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(BrokerState.self, from: data) else { return }

        self.queues = state.queues
        self.topics = state.topics
        self.users = Dictionary(uniqueKeysWithValues: state.users.map { ($0, Queue(name: "queue_\($0)")) })
        self.offlineMessages = state.offlineMessages
        self.dmContacts = state.dmContacts
        self.dmHistory = state.dmHistory
        self.topicHistory = state.topicHistory
    }
    
    func queueOfflineMessage(for user: String, message: String) {
        offlineMessages[user, default: []].append(message)
    }
    
    func getOfflineMessages(for user: String) -> [String]? {
        return offlineMessages[user]
    }
    
    func clearOfflineMessages(for user: String) {
        offlineMessages[user] = []
    }
    
    var dmHistory: [String: [String]] = [:]
    var topicHistory: [String: [String]] = [:]

    private func dmKey(_ u1: String, _ u2: String) -> String {
        [u1, u2].sorted().joined(separator: "|")
    }
    
    func addDMMessage(sender: String, recipient: String, message: String) {
        let key = dmKey(sender, recipient)
        dmHistory[key, default: []].append(message)
        if dmHistory[key]!.count > 20 { dmHistory[key]!.removeFirst() } // keep last 20
    }

    func addTopicMessage(topic: String, message: String) {
        topicHistory[topic, default: []].append(message)
        if topicHistory[topic]!.count > 50 { topicHistory[topic]!.removeFirst() }
    }

    func getDMHistory(for user: String) -> [String: [String]] {
        dmHistory.filter { $0.key.contains(user) }
    }
}

