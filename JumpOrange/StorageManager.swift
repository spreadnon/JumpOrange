import Foundation
import Combine
import SwiftUI

struct JumpSession: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let jumpCount: Int
    let duration: TimeInterval
    let caloriesBurned: Double // Simple heuristic
}

struct DailyRecord: Identifiable, Codable {
    var id: String { dateString }
    let dateString: String // e.g. "2023-10-27"
    var totalJumps: Int
    var sessions: [JumpSession]
}

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
    
    init() {
        loadRecords()
    }
    
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
            dailyRecords.insert(newRecord, at: 0) // Newest first
        }
        
        persistRecords()
    }
    
    func getTodayTotal() -> Int {
        let todayString = currentDayString()
        return dailyRecords.first(where: { $0.dateString == todayString })?.totalJumps ?? 0
    }
    
    // A simple heuristic for jumping rope: ~10-15 calories per minute depending on intensity.
    // Or just a raw calculation based on jump counts (e.g., 0.1 calories per jump).
    private func calculateCalories(jumps: Int, duration: TimeInterval) -> Double {
        return Double(jumps) * 0.14  // Approximate
    }
    
    private func currentDayString() -> String {
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
