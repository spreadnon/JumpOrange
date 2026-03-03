import Foundation
import Combine

// MARK: - Achievement Model

struct Achievement: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let icon: String          // SF Symbol name
    let category: AchievementCategory
    var isUnlocked: Bool
    var unlockedDate: Date?
    
    enum AchievementCategory: String, Codable, CaseIterable {
        case milestone = "里程碑"
        case streak = "连续打卡"
        case challenge = "每日挑战"
        case rhythm = "节奏游戏"
    }
}

// MARK: - AchievementManager

class AchievementManager: ObservableObject {
    @Published var achievements: [Achievement] = []
    
    private var storageManager: StorageManager
    private var cancellables = Set<AnyCancellable>()
    
    /// Newly unlocked achievements for UI display
    @Published var recentlyUnlocked: Achievement? = nil
    
    init(storageManager: StorageManager = StorageManager()) {
        self.storageManager = storageManager
        setupAchievements()
        loadUnlockedState()
    }
    
    /// Call this to inject the real StorageManager after init
    func configure(with storage: StorageManager) {
        self.storageManager = storage
        loadUnlockedState()
    }
    
    // MARK: - Setup
    
    private func setupAchievements() {
        achievements = [
            // Milestones (all-time total jumps)
            Achievement(id: "first_jump", title: "第一跳", description: "完成你的第一次跳跃", icon: "figure.jump", category: .milestone, isUnlocked: false),
            Achievement(id: "jumps_100", title: "百次飞跃", description: "累计跳跃100次", icon: "flame", category: .milestone, isUnlocked: false),
            Achievement(id: "jumps_500", title: "五百连击", description: "累计跳跃500次", icon: "flame.fill", category: .milestone, isUnlocked: false),
            Achievement(id: "jumps_1000", title: "千次突破", description: "累计跳跃1000次", icon: "star", category: .milestone, isUnlocked: false),
            Achievement(id: "jumps_5000", title: "五千壮举", description: "累计跳跃5000次", icon: "star.fill", category: .milestone, isUnlocked: false),
            Achievement(id: "jumps_10000", title: "万次传奇", description: "累计跳跃10000次", icon: "crown", category: .milestone, isUnlocked: false),
            
            // Streaks (consecutive days)
            Achievement(id: "streak_3", title: "三日坚持", description: "连续3天跳跃", icon: "3.circle.fill", category: .streak, isUnlocked: false),
            Achievement(id: "streak_7", title: "一周达人", description: "连续7天跳跃", icon: "7.circle.fill", category: .streak, isUnlocked: false),
            Achievement(id: "streak_14", title: "两周勇士", description: "连续14天跳跃", icon: "14.circle", category: .streak, isUnlocked: false),
            Achievement(id: "streak_30", title: "月度冠军", description: "连续30天跳跃", icon: "trophy", category: .streak, isUnlocked: false),
            
            // Challenge completions
            Achievement(id: "challenge_1", title: "初次挑战", description: "完成1个每日挑战", icon: "checkmark.circle", category: .challenge, isUnlocked: false),
            Achievement(id: "challenge_5", title: "挑战新星", description: "完成5个每日挑战", icon: "checkmark.circle.fill", category: .challenge, isUnlocked: false),
            Achievement(id: "challenge_10", title: "挑战高手", description: "完成10个每日挑战", icon: "rosette", category: .challenge, isUnlocked: false),
            Achievement(id: "challenge_20", title: "挑战之王", description: "完成20个每日挑战", icon: "crown.fill", category: .challenge, isUnlocked: false),
            
            // Rhythm
            Achievement(id: "rhythm_first", title: "节奏入门", description: "完成第一次节奏游戏", icon: "music.note", category: .rhythm, isUnlocked: false),
            Achievement(id: "rhythm_s_rank", title: "节奏大师", description: "在节奏游戏中获得S评级", icon: "music.note.list", category: .rhythm, isUnlocked: false),
        ]
    }
    
    // MARK: - Check & Unlock
    
    /// Check milestone achievements based on total jumps
    func checkMilestones(totalJumps: Int) {
        let milestoneMap: [(String, Int)] = [
            ("first_jump", 1),
            ("jumps_100", 100),
            ("jumps_500", 500),
            ("jumps_1000", 1000),
            ("jumps_5000", 5000),
            ("jumps_10000", 10000),
        ]
        
        for (id, threshold) in milestoneMap {
            if totalJumps >= threshold {
                unlock(id: id)
            }
        }
    }
    
    /// Check streak achievements
    func checkStreaks(currentStreak: Int) {
        let streakMap: [(String, Int)] = [
            ("streak_3", 3),
            ("streak_7", 7),
            ("streak_14", 14),
            ("streak_30", 30),
        ]
        
        for (id, threshold) in streakMap {
            if currentStreak >= threshold {
                unlock(id: id)
            }
        }
    }
    
    /// Check challenge completion count achievements
    func checkChallenges(completedCount: Int) {
        let challengeMap: [(String, Int)] = [
            ("challenge_1", 1),
            ("challenge_5", 5),
            ("challenge_10", 10),
            ("challenge_20", 20),
        ]
        
        for (id, threshold) in challengeMap {
            if completedCount >= threshold {
                unlock(id: id)
            }
        }
    }
    
    /// Check rhythm achievements
    func checkRhythmFirst() {
        unlock(id: "rhythm_first")
    }
    
    func checkRhythmSRank(perfectPercent: Double) {
        if perfectPercent > 90 {
            unlock(id: "rhythm_s_rank")
        }
    }
    
    // MARK: - Unlock Logic
    
    private func unlock(id: String) {
        guard let index = achievements.firstIndex(where: { $0.id == id }) else { return }
        guard !achievements[index].isUnlocked else { return }
        
        let now = Date()
        achievements[index].isUnlocked = true
        achievements[index].unlockedDate = now
        
        // Persist
        storageManager.saveAchievementUnlocked(id: id, date: now)
        
        // Notify UI
        recentlyUnlocked = achievements[index]
        
        // Post notification for voice manager
        NotificationCenter.default.post(
            name: .didUnlockAchievement,
            object: nil,
            userInfo: ["title": achievements[index].title]
        )
    }
    
    // MARK: - Persistence
    
    private func loadUnlockedState() {
        let unlocked = storageManager.getUnlockedAchievements()
        for (id, timestamp) in unlocked {
            if let index = achievements.firstIndex(where: { $0.id == id }) {
                achievements[index].isUnlocked = true
                achievements[index].unlockedDate = Date(timeIntervalSince1970: timestamp)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var unlockedCount: Int {
        achievements.filter { $0.isUnlocked }.count
    }
    
    var totalCount: Int {
        achievements.count
    }
    
    func achievements(for category: Achievement.AchievementCategory) -> [Achievement] {
        achievements.filter { $0.category == category }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let didUnlockAchievement = Notification.Name("didUnlockAchievement")
}
