//
//  ContentView.swift
//  JumpOrange
//
//  Created by Jeremy chen on 2026/2/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "play.fill")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "chart.bar.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.orange)
    }
}

#Preview {
    ContentView()
        .environmentObject(MotionManager())
        .environmentObject(StorageManager())
        .environmentObject(VoiceManager.shared)
}
