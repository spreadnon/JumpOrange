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
    @StateObject private var achievementManager = AchievementManager()
    @StateObject private var dailyChallengeManager = DailyChallengeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(motionManager)
                .environmentObject(storageManager)
                .environmentObject(voiceManager)
                .environmentObject(achievementManager)
                .environmentObject(dailyChallengeManager)
                .onAppear {
                    // Inject real storage manager into dependent managers
                    achievementManager.configure(with: storageManager)
                    dailyChallengeManager.configure(with: storageManager)
                    
                    // Setup achievement observer for voice feedback
                    NotificationCenter.default.addObserver(
                        forName: .didUnlockAchievement,
                        object: nil,
                        queue: .main
                    ) { notification in
                        if let title = notification.userInfo?["title"] as? String {
                            voiceManager.speakAchievementUnlocked(title: title)
                        }
                    }
                    
                    // Setup challenge completion observer for voice feedback
                    NotificationCenter.default.addObserver(
                        forName: .didCompleteChallenge,
                        object: nil,
                        queue: .main
                    ) { notification in
                        if let title = notification.userInfo?["title"] as? String {
                            voiceManager.speakChallengeCompleted(title: title)
                        }
                        if let count = notification.userInfo?["completedCount"] as? Int {
                            achievementManager.checkChallenges(completedCount: count)
                        }
                    }
                }
        }
    }
}
