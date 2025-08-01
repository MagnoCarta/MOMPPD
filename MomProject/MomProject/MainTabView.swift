//
//  MainTabView.swift
//  MomProject
//
//  Created by Gilberto Magno on 30/07/25.
//


import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            UsersView()
                .tabItem { Label("Users", systemImage: "person.2.fill") }
            TopicsView()
                .tabItem { Label("Topics", systemImage: "bubble.left.and.bubble.right.fill") }
        }
    }
}
