import Foundation
import Combine
import SwiftUI

// MARK: - Models

struct JumpSession: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let jumpCount: Int
    let duration: TimeInterval
    let caloriesBurned: Double
}

struct DailyRecord: Identifiable, Codable {
    var id: String { dateString }
    let dateString: String // e.g. "2023-10-27"
    var totalJumps: Int
    var sessions: [JumpSession]
}

// MARK: - StorageManager

class StorageManager: ObservableObject {
    static let shared = StorageManager()
    
    // User Preferences
    @AppStorage("dailyGoal") var dailyGoal: Int = 500
    @AppStorage("voiceStyle") var voiceStyleString: String = VoiceManager.VoiceStyle.standard.rawValue
    @AppStorage("voiceInterval") var voiceInterval: Int = 10
    
    // Low, Medium, High mapping to thresholds
    @AppStorage("jumpSensitivity") var jumpSensitivity: Int = 1 // 0: Low, 1: Medium, 2: High
    
    // Data Storage
    @Published var dailyRecords: [DailyRecord] = []
    
    private let calendar = Calendar.current
    private let dataKey = "JumpOrange_DailyRecords"
    
    // Achievement persistence keys
    private let achievementsKey = "JumpOrange_Achievements"
    private let completedChallengesCountKey = "JumpOrange_CompletedChallengesCount"
    private let dailyChallengeKey = "JumpOrange_DailyChallenge"
    
    init() {
        loadRecords()
    }
    
    // MARK: - Session Management
    
    func saveSession(jumps: Int, duration: TimeInterval) {
        guard jumps > 0 else { return }
        
        let calories = calculateCalories(jumps: jumps, duration: duration)
        let session = JumpSession(date: Date(), jumpCount: jumps, duration: duration, caloriesBurned: calories)
        
        let todayString = currentDayString()
        
        if let index = dailyRecords.firstIndex(where: { $0.dateString == todayString }) {
            dailyRecords[index].sessions.append(session)
            dailyRecords[index].totalJumps += jumps
        } else {
            let newRecord = DailyRecord(dateString: todayString, totalJumps: jumps, sessions: [session])
            dailyRecords.insert(newRecord, at: 0)
        }
        
        persistRecords()
    }
    
    func getTodayTotal() -> Int {
        let todayString = currentDayString()
        return dailyRecords.first(where: { $0.dateString == todayString })?.totalJumps ?? 0
    }
    
    // MARK: - All-Time Total
    
    /// Total jumps across all recorded days
    var totalAllTimeJumps: Int {
        dailyRecords.reduce(0) { $0 + $1.totalJumps }
    }
    
    // MARK: - Streak Tracking
    
    /// Calculate the current consecutive-day streak (days with at least 1 jump)
    var currentStreak: Int {
        guard !dailyRecords.isEmpty else { return 0 }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Get sorted unique dates that have jumps
        let datesWithJumps: [Date] = dailyRecords
            .filter { $0.totalJumps > 0 }
            .compactMap { formatter.date(from: $0.dateString) }
            .sorted(by: >)
        
        guard !datesWithJumps.isEmpty else { return 0 }
        
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // The streak must include today or yesterday
        let mostRecentDay = calendar.startOfDay(for: datesWithJumps[0])
        guard mostRecentDay >= yesterday else { return 0 }
        
        var streak = 1
        var currentDate = mostRecentDay
        
        for i in 1..<datesWithJumps.count {
            let expectedPreviousDay = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            let thisDay = calendar.startOfDay(for: datesWithJumps[i])
            
            if thisDay == expectedPreviousDay {
                streak += 1
                currentDate = thisDay
            } else if thisDay == currentDate {
                // Same day, skip duplicates
                continue
            } else {
                break
            }
        }
        
        return streak
    }
    
    /// Longest streak ever recorded
    var longestStreak: Int {
        guard !dailyRecords.isEmpty else { return 0 }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let datesWithJumps: [Date] = dailyRecords
            .filter { $0.totalJumps > 0 }
            .compactMap { formatter.date(from: $0.dateString) }
            .sorted()
        
        guard !datesWithJumps.isEmpty else { return 0 }
        
        var longest = 1
        var current = 1
        
        for i in 1..<datesWithJumps.count {
            let prev = calendar.startOfDay(for: datesWithJumps[i - 1])
            let curr = calendar.startOfDay(for: datesWithJumps[i])
            let expectedNext = calendar.date(byAdding: .day, value: 1, to: prev)!
            
            if curr == expectedNext {
                current += 1
                longest = max(longest, current)
            } else if curr != prev {
                current = 1
            }
        }
        
        return longest
    }
    
    // MARK: - Achievement Persistence
    
    func saveAchievementUnlocked(id: String, date: Date) {
        var unlocked = getUnlockedAchievements()
        unlocked[id] = date.timeIntervalSince1970
        if let data = try? JSONEncoder().encode(unlocked) {
            UserDefaults.standard.set(data, forKey: achievementsKey)
        }
    }
    
    func getUnlockedAchievements() -> [String: Double] {
        guard let data = UserDefaults.standard.data(forKey: achievementsKey),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        return dict
    }
    
    // MARK: - Challenge Persistence
    
    var completedChallengesCount: Int {
        get { UserDefaults.standard.integer(forKey: completedChallengesCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: completedChallengesCountKey) }
    }
    
    func saveDailyChallengeState(_ data: Data) {
        UserDefaults.standard.set(data, forKey: dailyChallengeKey)
    }
    
    func loadDailyChallengeState() -> Data? {
        UserDefaults.standard.data(forKey: dailyChallengeKey)
    }
    
    // MARK: - Reset All Data
    
    func resetAllData() {
        dailyRecords.removeAll()
        persistRecords()
        
        UserDefaults.standard.removeObject(forKey: achievementsKey)
        UserDefaults.standard.removeObject(forKey: completedChallengesCountKey)
        UserDefaults.standard.removeObject(forKey: dailyChallengeKey)
        
        dailyGoal = 500
        jumpSensitivity = 1
        voiceInterval = 10
        voiceStyleString = VoiceManager.VoiceStyle.standard.rawValue
    }
    
    // MARK: - Private Helpers
    
    private func calculateCalories(jumps: Int, duration: TimeInterval) -> Double {
        return Double(jumps) * 0.14
    }
    
    func currentDayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func persistRecords() {
        if let data = try? JSONEncoder().encode(dailyRecords) {
            UserDefaults.standard.set(data, forKey: dataKey)
        }
    }
    
    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: dataKey),
           let records = try? JSONDecoder().decode([DailyRecord].self, from: data) {
            self.dailyRecords = records
        }
    }
}
