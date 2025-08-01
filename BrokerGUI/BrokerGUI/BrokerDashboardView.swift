//
//  BrokerDashboardView.swift
//  BrokerGUI
//
//  Created by Gilberto Magno on 30/07/25.
//

import SwiftUI

struct BrokerDashboardView: View {
    @EnvironmentObject var brokerVM: BrokerViewModel
    @State private var newQueueName = ""
    @State private var newTopicName = ""
    @State private var newUserName = ""
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView(.vertical) {
                    VStack(spacing: 20) {
                        // Queues
                        sectionTitle("📦 Queues")
                        listSection {
                            ForEach(brokerVM.queues, id: \.name) { q in
                                HStack { Text(q.name); Spacer(); Text("\(q.messages.count) msgs").foregroundColor(.secondary) }
                            }
                        }
                        inputRow(placeholder: "New Queue", text: $newQueueName, action: { brokerVM.addQueue(newQueueName); newQueueName = "" })
                        
                        // Topics
                        sectionTitle("📢 Topics")
                        listSection {
                            ForEach(brokerVM.topics, id: \.name) { topic in
                                VStack(alignment: .leading) {
                                    Text(topic.name).bold()
                                    Text("Subscribers: \(topic.subscribers.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        inputRow(placeholder: "New Topic", text: $newTopicName, action: { brokerVM.addTopic(newTopicName); newTopicName = "" })
                        
                        // Users
                        sectionTitle("👥 Users")
                        listSection {
                            ForEach(Array(brokerVM.users.keys), id: \.self) { user in
                                VStack(alignment: .leading) {
                                    Text(user).bold()
                                    if let msgs = brokerVM.offlineMessages[user], !msgs.isEmpty {
                                        Text("Offline Messages: \(msgs.count)")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                        inputRow(placeholder: "New User", text: $newUserName, action: { brokerVM.createUser(newUserName); newUserName = "" })
                        
                        // Logs
                        sectionTitle("📜 Message Logs")
                        listSection {
                            ForEach(brokerVM.logs, id: \.self) { log in
                                Text(log).font(.caption2).foregroundColor(.gray)
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
            }
            .padding()
            .navigationTitle("MOM Broker Dashboard")
        }
    }
    
    // Helper UI builders
    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
    }
    private func listSection<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        VStack { content() }.frame(maxWidth: .infinity).padding(.vertical, 5).background(Color(.gray).opacity(0.35)).cornerRadius(8)
    }
    private func inputRow(placeholder: String, text: Binding<String>, action: @escaping () -> Void) -> some View {
        HStack {
            TextField(placeholder, text: text).textFieldStyle(RoundedBorderTextFieldStyle())
            Button("Add", action: action)
        }
    }
}

