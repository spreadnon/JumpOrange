import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("主页", systemImage: "house.fill")
                }
            
            RhythmGameView()
                .tabItem {
                    Label("节奏", systemImage: "music.note.list")
                }
            
            DailyChallengeView()
                .tabItem {
                    Label("挑战", systemImage: "bolt.fill")
                }
            
            AchievementsView()
                .tabItem {
                    Label("成就", systemImage: "trophy.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
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
        .environmentObject(AchievementManager())
        .environmentObject(DailyChallengeManager())
}
