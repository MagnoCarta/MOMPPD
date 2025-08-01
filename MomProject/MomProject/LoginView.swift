//
//  LoginView.swift
//  MomProject
//
//  Created by Gilberto Magno on 30/07/25.
//


import SwiftUI

//struct LoginView: View {
//    @State private var username: String = ""
//    @State private var showError: Bool = false
//    @State private var isLoggedIn: Bool = false
//    @StateObject private var client = UserClient.shared
//    
//    var body: some View {
//        if isLoggedIn {
//            MainTabView()
//                .environmentObject(client)
//        } else {
//            VStack(spacing: 20) {
//                Text("Login to MOM")
//                    .font(.largeTitle)
//                    .bold()
//                
//                TextField("Enter your username", text: $username)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .padding(.horizontal, 40)
//                    .multilineTextAlignment(.center)
//                
//                Button("Login") {
//                    Task {
//                        let success = await client.login(username: username)
//                        if success {
//                            isLoggedIn = true
//                        } else {
//                            showError = true
//                        }
//                    }
//                }
//                .buttonStyle(.borderedProminent)
//                .padding()
//                .disabled(username.isEmpty)
//                
//                if showError {
//                    Text("⚠️ Username already exists, choose another.")
//                        .foregroundColor(.red)
//                        .font(.caption)
//                }
//            }
//            .padding()
//        }
//    }
//}

struct LoginView: View {
    @State private var username = ""
    @State private var errorMessage = ""
    @State private var isLoggedIn = false
    @State private var isNewUser = true
    @StateObject private var client = UserClient.shared
    
    var body: some View {
        if isLoggedIn {
            MainTabView().environmentObject(client)
        } else {
            VStack(spacing: 20) {
                Text("MOM Login").font(.largeTitle).bold()
                TextField("Enter Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                HStack(spacing: 20) {
                    Button("Create Account") {
                        Task {
                            let success = await client.login(username: username, isNew: true)
                            isLoggedIn = success
                            if !success { errorMessage = "Username already taken" }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Login") {
                        Task {
                            let success = await client.login(username: username, isNew: false)
                            isLoggedIn = success
                            if !success { errorMessage = "User not found" }
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage).foregroundColor(.red).font(.caption)
                }
            }
            .padding()
        }
    }
}
