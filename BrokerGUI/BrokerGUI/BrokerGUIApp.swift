//
//  BrokerGUIApp.swift
//  BrokerGUI
//
//  Created by Gilberto Magno on 30/07/25.
//

import SwiftUI

@main
struct BrokerGUIApp: App {
    @StateObject private var brokerViewModel = BrokerViewModel()
    
    var body: some Scene {
        WindowGroup {
            BrokerDashboardView()
                .environmentObject(brokerViewModel)
                .onAppear {
                    brokerViewModel.startBroker()
                }
        }
    }
}
