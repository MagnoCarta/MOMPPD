//
//  BrokerViewModel.swift
//  BrokerGUI
//
//  Created by Gilberto Magno on 30/07/25.
//


import SwiftUI
import Combine

class BrokerViewModel: ObservableObject {
    @Published var queues: [Queue] = []
    @Published var topics: [Topic] = []
    @Published var users: [String: Queue] = [:]
    @Published var offlineMessages: [String: [String]] = [:]
    @Published var logs: [String] = [] // ✅ Live log feed
    
    private var broker: BrokerServer?
    
    func startBroker() {
        broker = BrokerServer(logHandler: { log in
            DispatchQueue.main.async {
                self.logs.insert(log, at: 0)
                if log.contains("Topic") || log.contains("subscribed") {
                    self.refreshData() // ✅ Refresh topics on change
                }
            }
        })
        broker?.manager.loadState()
        refreshData()
        DispatchQueue.global().async { self.broker?.start() }
    }
    
    func refreshData() {
        guard let manager = broker?.manager else { return }
        DispatchQueue.main.async {
            self.queues = manager.queues
            self.topics = manager.topics
            self.users = manager.users
            self.offlineMessages = manager.offlineMessages
        }
    }
    
    func addQueue(_ name: String) {
        broker?.manager.addQueue(name)
        broker?.manager.saveState()
        logEvent("➕ Queue '\(name)' added")
        refreshData()
    }
    
    func addTopic(_ name: String) {
        broker?.manager.addTopic(name)
        broker?.manager.saveState()
        logEvent("📢 Topic '\(name)' added")
        refreshData()
    }
    
    func createUser(_ name: String) {
        if broker?.manager.createUser(name) == true {
            broker?.manager.saveState()
            logEvent("👤 User '\(name)' created")
            refreshData()
        } else {
            logEvent("⚠️ User creation failed: '\(name)' already exists")
        }
    }
    
    private func logEvent(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logs.insert("[\(timestamp)] \(message)", at: 0)
    }
}
