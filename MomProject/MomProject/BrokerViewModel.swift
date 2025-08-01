//
//  BrokerViewModel.swift
//  MomProject
//
//  Created by Gilberto Magno on 30/07/25.
//


//import SwiftUI
//import Combine
//
//class BrokerViewModel: ObservableObject {
//    @Published var queues: [Queue] = []
//    @Published var topics: [Topic] = []
//    @Published var users: [String: Queue] = [:]
//    @Published var offlineMessages: [String: [String]] = [:]
//    
//    private var broker: BrokerServer?
//    
//    func startBroker() {
//        broker = BrokerServer()
//        broker?.manager.loadState()
//        refreshData()
//        DispatchQueue.global().async {
//            self.broker?.start()
//        }
//    }
//    
//    func refreshData() {
//        guard let manager = broker?.manager else { return }
//        DispatchQueue.main.async {
//            self.queues = manager.queues
//            self.topics = manager.topics
//            self.users = manager.users
//            self.offlineMessages = manager.offlineMessages
//        }
//    }
//    
//    func addQueue(_ name: String) {
//        broker?.manager.addQueue(name)
//        broker?.manager.saveState()
//        refreshData()
//    }
//    
//    func addTopic(_ name: String) {
//        broker?.manager.addTopic(name)
//        broker?.manager.saveState()
//        refreshData()
//    }
//    
//    func createUser(_ name: String) {
//        _ = broker?.manager.createUser(name)
//        broker?.manager.saveState()
//        refreshData()
//    }
//}
