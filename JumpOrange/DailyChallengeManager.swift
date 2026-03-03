import Foundation
import Combine

// MARK: - Challenge Type

enum ChallengeType: Codable, Equatable {
    case totalJumps(target: Int)
    case speedJump(count: Int, seconds: Int)
    case rhythmScore(grade: String)
    
    var displayDescription: String {
        switch self {
        case .totalJumps(let target):
            return "今天累计跳跃\(target)次"
        case .speedJump(let count, let seconds):
            return "在\(seconds)秒内跳跃\(count)次"
        case .rhythmScore(let grade):
            return "在节奏游戏中获得\(grade)评级或更高"
        }
    }
    
    var icon: String {
        switch self {
        case .totalJumps: return "figure.jump"
        case .speedJump: return "bolt"
        case .rhythmScore: return "music.note"
        }
    }
}

// MARK: - DailyChallenge Model

struct DailyChallenge: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let type: ChallengeType
    var isCompleted: Bool
    let dateString: String
    
    /// Progress value (0.0 - 1.0)
    var progress: Double
    var currentValue: Int
    
    var target: Int {
        switch type {
        case .totalJumps(let t): return t
        case .speedJump(let c, _): return c
        case .rhythmScore: return 1
        }
    }
}

// MARK: - DailyChallengeManager

class DailyChallengeManager: ObservableObject {
    @Published var todayChallenge: DailyChallenge?
    @Published var weekChallenges: [DailyChallenge] = []
    @Published var showCompletionAnimation: Bool = false
    
    private var storageManager: StorageManager
    private var jumpObserver: Any?
    
    // Challenge pool
    private let challengePool: [(String, ChallengeType)] = [
        ("轻松热身", .totalJumps(target: 50)),
        ("日常锻炼", .totalJumps(target: 100)),
        ("积极运动", .totalJumps(target: 200)),
        ("跳跃达人", .totalJumps(target: 300)),
        ("超级跳手", .totalJumps(target: 500)),
        ("极限跳跃", .totalJumps(target: 800)),
        ("千次挑战", .totalJumps(target: 1000)),
        ("闪电出击", .speedJump(count: 10, seconds: 15)),
        ("疾速连跳", .speedJump(count: 20, seconds: 25)),
        ("极速风暴", .speedJump(count: 30, seconds: 30)),
        ("速度之王", .speedJump(count: 50, seconds: 45)),
        ("节奏初体验", .rhythmScore(grade: "D")),
        ("节奏进阶", .rhythmScore(grade: "C")),
        ("节奏高手", .rhythmScore(grade: "B")),
        ("节奏大师", .rhythmScore(grade: "A")),
    ]
    
    init(storageManager: StorageManager = StorageManager()) {
        self.storageManager = storageManager
        loadOrGenerateToday()
        loadWeekHistory()
        setupObservers()
    }
    
    /// Call this to inject the real StorageManager
    func configure(with storage: StorageManager) {
        self.storageManager = storage
        loadOrGenerateToday()
        loadWeekHistory()
    }
    
    // MARK: - Daily Generation
    
    private func loadOrGenerateToday() {
        let todayString = currentDayString()
        
        // Try to load saved challenge
        if let data = storageManager.loadDailyChallengeState(),
           let saved = try? JSONDecoder().decode(DailyChallenge.self, from: data),
           saved.dateString == todayString {
            todayChallenge = saved
            return
        }
        
        // Generate new challenge for today
        let challenge = generateChallenge(for: todayString)
        todayChallenge = challenge
        saveChallenge()
    }
    
    private func generateChallenge(for dateString: String) -> DailyChallenge {
        // Deterministic selection based on date hash
        let hash = abs(dateString.hashValue)
        let index = hash % challengePool.count
        let (title, type) = challengePool[index]
        
        return DailyChallenge(
            id: dateString,
            title: title,
            description: type.displayDescription,
            type: type,
            isCompleted: false,
            dateString: dateString,
            progress: 0,
            currentValue: 0
        )
    }
    
    // MARK: - Progress Updates
    
    func updateProgress(todayJumps: Int) {
        guard var challenge = todayChallenge, !challenge.isCompleted else { return }
        
        switch challenge.type {
        case .totalJumps(let target):
            challenge.currentValue = todayJumps
            challenge.progress = min(Double(todayJumps) / Double(target), 1.0)
            if todayJumps >= target {
                completeChallenge(&challenge)
            }
        default:
            break
        }
        
        todayChallenge = challenge
        saveChallenge()
    }
    
    /// Called when a speed jump session is completed
    func reportSpeedJump(count: Int, seconds: Int) {
        guard var challenge = todayChallenge, !challenge.isCompleted else { return }
        
        if case .speedJump(let targetCount, let targetSeconds) = challenge.type {
            if count >= targetCount && seconds <= targetSeconds {
                challenge.currentValue = targetCount
                challenge.progress = 1.0
                completeChallenge(&challenge)
            } else {
                challenge.currentValue = count
                challenge.progress = min(Double(count) / Double(targetCount), 0.99)
            }
            todayChallenge = challenge
            saveChallenge()
        }
    }
    
    /// Called when a rhythm game finishes
    func reportRhythmGrade(_ grade: String) {
        guard var challenge = todayChallenge, !challenge.isCompleted else { return }
        
        if case .rhythmScore(let targetGrade) = challenge.type {
            let gradeOrder = ["D": 0, "C": 1, "B": 2, "A": 3, "S": 4]
            let achieved = gradeOrder[grade] ?? 0
            let needed = gradeOrder[targetGrade] ?? 0
            
            if achieved >= needed {
                challenge.currentValue = 1
                challenge.progress = 1.0
                completeChallenge(&challenge)
            }
            todayChallenge = challenge
            saveChallenge()
        }
    }
    
    private func completeChallenge(_ challenge: inout DailyChallenge) {
        challenge.isCompleted = true
        challenge.progress = 1.0
        
        // Update completed count
        storageManager.completedChallengesCount += 1
        
        // Show animation
        showCompletionAnimation = true
        
        // Post notification
        NotificationCenter.default.post(
            name: .didCompleteChallenge,
            object: nil,
            userInfo: [
                "title": challenge.title,
                "completedCount": storageManager.completedChallengesCount
            ]
        )
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        // Listen for rhythm game results
        NotificationCenter.default.addObserver(
            forName: .didFinishRhythmGame,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let grade = notification.userInfo?["grade"] as? String {
                self?.reportRhythmGrade(grade)
            }
        }
    }
    
    // MARK: - Week History
    
    private func loadWeekHistory() {
        let key = "JumpOrange_WeekChallenges"
        var challenges: [DailyChallenge] = []
        
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([DailyChallenge].self, from: data) {
            challenges = saved
        }
        
        // Add today if not in list
        let todayString = currentDayString()
        if let today = todayChallenge, !challenges.contains(where: { $0.dateString == todayString }) {
            challenges.insert(today, at: 0)
        } else if let today = todayChallenge, let index = challenges.firstIndex(where: { $0.dateString == todayString }) {
            challenges[index] = today
        }
        
        // Keep only last 7 days
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        challenges = challenges.filter {
            if let date = formatter.date(from: $0.dateString) {
                return date >= sevenDaysAgo
            }
            return false
        }
        
        weekChallenges = challenges.sorted { $0.dateString > $1.dateString }
        
        if let data = try? JSONEncoder().encode(weekChallenges) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    // MARK: - Persistence
    
    private func saveChallenge() {
        guard let challenge = todayChallenge else { return }
        if let data = try? JSONEncoder().encode(challenge) {
            storageManager.saveDailyChallengeState(data)
        }
        // Also update week history
        loadWeekHistory()
    }
    
    var completedCount: Int {
        storageManager.completedChallengesCount
    }
    
    // MARK: - Helpers
    
    private func currentDayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Notification

extension Notification.Name {
    static let didCompleteChallenge = Notification.Name("didCompleteChallenge")
}
