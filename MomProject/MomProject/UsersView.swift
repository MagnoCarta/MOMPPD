//
//  UsersView.swift
//  MomProject
//
//  Created by Gilberto Magno on 30/07/25.
//

import SwiftUI

struct UsersView: View {
    @EnvironmentObject var client: UserClient
    @State private var newDMUser: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(client.dmUsers.keys.sorted().filter { !$0.contains("[")}, id: \.self) { user in
                        NavigationLink(destination: ChatDMView(otherUser: user)) {
                            Text(user).font(.headline)
                        }
                    }
                }
                
                Divider()
                
                HStack {
                    TextField("Enter username for DM", text: $newDMUser)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Add DM") {
                        if !newDMUser.isEmpty {
                            client.sendDM(to: newDMUser, content: "You added \(newDMUser)")
                            newDMUser = ""
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Direct Messages")
        }
    }
}

