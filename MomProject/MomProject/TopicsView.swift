//
//  TopicsView.swift
//  MomProject
//
//  Created by Gilberto Magno on 30/07/25.
//

import SwiftUI

struct TopicsView: View {
    @EnvironmentObject var client: UserClient
    @State private var newTopic: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(client.topics, id: \.self) { topic in
                        NavigationLink(destination: TopicChatView(topic: topic)) {
                            Text("#\(topic)").font(.headline)
                        }
                    }
                }
                
                Divider()
                
                HStack {
                    TextField("Enter topic name", text: $newTopic)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Join/Create Topic") {
                        if !newTopic.isEmpty {
                            client.subscribe(to: newTopic)
                            newTopic = ""
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Topics")
        }
    }
}

