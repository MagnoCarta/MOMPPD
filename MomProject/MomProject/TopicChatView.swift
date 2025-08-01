//
//  TopicChatView.swift
//  MomProject
//
//  Created by Gilberto Magno on 30/07/25.
//


import SwiftUI

struct TopicChatView: View {
    @EnvironmentObject var client: UserClient
    let topic: String
    
    @State private var newMessage = ""
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(filteredMessages(), id: \.id) { msg in
                        Text("\(msg.sender): \(msg.text.replacingOccurrences(of: "[\(topic)] ", with: ""))")
                            .padding(8)
                            .background(msg.sender == client.username ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity, alignment: msg.sender == client.username ? .trailing : .leading)
                    }
                }
            }
            .padding()
            
            Divider()
            
            HStack {
                TextField("Send message to \(topic)...", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Send") {
                    if !newMessage.isEmpty {
                        client.sendTopicMessage(to: topic, content: newMessage)
                        newMessage = ""
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("#\(topic)")
    }
    
    private func filteredMessages() -> [Message] {
        client.messages.filter { $0.text.starts(with: "[\(topic)]") }
    }

}
