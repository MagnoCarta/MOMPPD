//
//  BrokerServer.swift
//  MomProject
//
//  Created by Gilberto Magno on 30/07/25.
//

//
//import Network
//import Foundation
//
//class BrokerServer {
//    var listener: NWListener!
//    var connections: [NWConnection] = []
//    var manager = BrokerManager()
//    
//    func start() {
//        listener = try! NWListener(using: .tcp, on: 8080)
//        listener.newConnectionHandler = { conn in
//            self.connections.append(conn)
//            conn.start(queue: .global())
//            self.receive(from: conn)
//        }
//        listener.start(queue: .global())
//        print("Broker running on port 8080")
//    }
//    
//    func receive(from connection: NWConnection) {
//        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, _ in
//            if let data = data, let message = String(data: data, encoding: .utf8) {
//                print("Received: \(message)")
//                self.handleCommand(message, from: connection)
//            }
//            self.receive(from: connection)
//        }
//    }
//    
//    func handleCommand(_ command: String, from conn: NWConnection) {
//        if command.starts(with: "CREATE_USER:") {
//            let name = command.replacingOccurrences(of: "CREATE_USER:", with: "")
//            let success = manager.createUser(name)
//            send(success ? "User \(name) created" : "Duplicate user name", to: conn)
//        } else if command.starts(with: "ADD_QUEUE:") {
//            let q = command.replacingOccurrences(of: "ADD_QUEUE:", with: "")
//            manager.addQueue(q)
//            send("Queue \(q) added", to: conn)
//        } else if command.starts(with: "ADD_TOPIC:") {
//            let t = command.replacingOccurrences(of: "ADD_TOPIC:", with: "")
//            manager.addTopic(t)
//            send("Topic \(t) added", to: conn)
//        } else if command == "LIST_QUEUES" {
//            send(manager.listQueues().joined(separator: "\n"), to: conn)
//        } else if command == "LIST_TOPICS" {
//            send(manager.listTopics().joined(separator: "\n"), to: conn)
//        } else if command.starts(with: "MSG:") {
//            let msg = command.replacingOccurrences(of: "MSG:", with: "")
//            for c in connections { send("MSG: \(msg)", to: c) }
//        }
//    }
//    
//    func send(_ message: String, to conn: NWConnection) {
//        conn.send(content: message.data(using: .utf8), completion: .contentProcessed { _ in })
//    }
//}
//
//class Queue {
//    var name: String
//    var messages: [String] = []
//    init(name: String) { self.name = name }
//}
//
//class Topic {
//    var name: String
//    var subscribers: [String] = []
//    init(name: String) { self.name = name }
//}
//
//class BrokerManager {
//    var queues: [Queue] = []
//    var topics: [Topic] = []
//    var users: [String: Queue] = [:]
//    
//    func addQueue(_ name: String) { queues.append(Queue(name: name)) }
//    func listQueues() -> [String] { queues.map { "\($0.name) (\($0.messages.count) msgs)" } }
//    func addTopic(_ name: String) { topics.append(Topic(name: name)) }
//    func listTopics() -> [String] { topics.map { $0.name } }
//    func createUser(_ name: String) -> Bool {
//        guard users[name] == nil else { return false }
//        let q = Queue(name: "queue_\(name)")
//        users[name] = q
//        queues.append(q)
//        return true
//    }
//}
//
////let server = BrokerServer()
////server.start()
////RunLoop.main.run()
