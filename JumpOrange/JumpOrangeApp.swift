//
//  JumpOrangeApp.swift
//  JumpOrange
//
//  Created by Jeremy chen on 2026/2/25.
//

import SwiftUI

@main
struct JumpOrangeApp: App {
    @StateObject private var motionManager = MotionManager()
    @StateObject private var storageManager = StorageManager()
    @StateObject private var voiceManager = VoiceManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(motionManager)
                .environmentObject(storageManager)
                .environmentObject(voiceManager)
        }
    }
}
