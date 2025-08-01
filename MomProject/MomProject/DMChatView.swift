//
//  DMChatView.swift
//  MomProject
//
//  Created by Gilberto Magno on 30/07/25.
//

//struct DMChatView: View {
//    @EnvironmentObject var client: UserClient
//    let user: String
//    
//    @State private var newMessage = ""
//    
//    var body: some View {
//        VStack {
//            ScrollView {
//                LazyVStack(alignment: .leading, spacing: 8) {
//                    ForEach(filteredMessages(), id: \.self) { msg in
//                        Text(msg)
//                            .padding(8)
//                            .background(msg.contains("from \(user)") ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
//                            .cornerRadius(8)
//                            .frame(maxWidth: .infinity, alignment: msg.contains("from \(user)") ? .leading : .trailing)
//                    }
//                }
//            }
//            .padding()
//            
//            Divider()
//            
//            HStack {
//                TextField("Type a message...", text: $newMessage)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                Button("Send") {
//                    if !newMessage.isEmpty {
//                        client.sendDM(to: user, content: newMessage)
//                        newMessage = ""
//                    }
//                }
//                .buttonStyle(.borderedProminent)
//            }
//            .padding()
//        }
//        .navigationTitle(user)
//    }
//    
//    private func filteredMessages() -> [String] {
//        client.messages.filter { $0.contains("DM from \(user)") || $0.contains("DM from \(client.username)") && $0.contains(user) }
//    }
//}

import SwiftUI

struct ChatDMView: View {
    @EnvironmentObject var client: UserClient
    let otherUser: String
    
    @State private var input: String = ""
    
    var messages: [Message] {
        var seenTexts = Set<String>()
        return client.messages
            .filter { $0.sender == otherUser || $0.sender == client.username }
            .reversed() // Reverse to keep the most recent message if duplicated
            .filter { message in
                if seenTexts.contains(message.text) {
                    return false
                } else {
                    seenTexts.insert(message.text)
                    return true
                }
            }
            .reversed() // Reverse back to original order
    }

    
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { msg in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(msg.sender == client.username ? "You" : msg.sender)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(msg.text)
                                        .padding(8)
                                        .background(msg.sender == client.username ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                    HStack(spacing: 4) {
                                        Text(msg.timestamp, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        if msg.sender == client.username {
                                            Text(msg.delivered ? "✅✅" : "✅")
                                                .font(.caption2)
                                        }
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in proxy.scrollTo(messages.last?.id) }
            }
            
            if client.typingIndicators.contains(otherUser) {
                Text("\(otherUser) is typing...")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 4)
            }
            
            Divider()
            
            HStack {
                TextField("Message...", text: $input, onEditingChanged: { _ in
                    client.sendTyping(to: otherUser)
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Send") {
                    client.sendDM(to: otherUser, content: input)
                    input = ""
                }
            }
            .padding()
        }
        .navigationTitle("\(otherUser) \(client.dmUsers[otherUser] == true ? "🟢" : "⚫️")")
        .navigationBarTitleDisplayMode(.inline)
    }
}
