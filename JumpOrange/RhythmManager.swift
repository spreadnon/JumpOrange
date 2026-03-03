import Foundation
import Combine
import AudioToolbox

// MARK: - BeatMap Model

struct BeatMap: Identifiable {
    let id = UUID()
    let name: String
    let bpm: Int
    let duration: TimeInterval   // seconds
    let difficulty: Difficulty
    let beatPattern: [TimeInterval] // timestamps in seconds from start
    
    enum Difficulty: String {
        case easy = "简单"
        case medium = "中等"
        case hard = "困难"
        
        var color: String {
            switch self {
            case .easy: return "green"
            case .medium: return "orange"
            case .hard: return "red"
            }
        }
        
        var icon: String {
            switch self {
            case .easy: return "hare"
            case .medium: return "flame"
            case .hard: return "bolt.fill"
            }
        }
    }
}

// MARK: - Game State

enum RhythmGameState: Equatable {
    case idle
    case countdown(Int) // 3, 2, 1
    case playing
    case finished
}

// MARK: - Hit Quality

enum HitQuality {
    case perfect
    case good
    case miss
}

// MARK: - RhythmManager

class RhythmManager: ObservableObject {
    // Game state
    @Published var gameState: RhythmGameState = .idle
    @Published var selectedTrack: BeatMap?
    
    // Scoring
    @Published var perfectCount: Int = 0
    @Published var goodCount: Int = 0
    @Published var missCount: Int = 0
    @Published var score: Int = 0
    @Published var combo: Int = 0
    @Published var maxCombo: Int = 0
    
    // Progress
    @Published var currentBeatIndex: Int = 0
    @Published var progress: Double = 0
    @Published var timeRemaining: TimeInterval = 0
    
    // Last hit quality for UI feedback
    @Published var lastHitQuality: HitQuality? = nil
    
    // Available tracks
    let tracks: [BeatMap]
    
    // Internal timing
    private var gameStartTime: Date?
    private var gameTimer: Timer?
    private var beatTimer: Timer?
    private var countdownTimer: Timer?
    private var processedBeats: Set<Int> = [] // Track which beats were already scored as miss
    private var hitBeats: Set<Int> = []        // Track which beats were hit by jumps
    
    // Jump observer
    private var jumpObserver: Any?
    
    // Thresholds (in seconds)
    private let perfectThreshold: TimeInterval = 0.08  // 80ms
    private let goodThreshold: TimeInterval = 0.20      // 200ms
    
    init() {
        // Generate 3 built-in tracks
        tracks = [
            RhythmManager.generateTrack(name: "热身节拍", bpm: 80, duration: 60, difficulty: .easy),
            RhythmManager.generateTrack(name: "跳动街区", bpm: 120, duration: 90, difficulty: .medium),
            RhythmManager.generateTrack(name: "极速挑战", bpm: 160, duration: 90, difficulty: .hard),
        ]
    }
    
    // MARK: - Track Generation
    
    private static func generateTrack(name: String, bpm: Int, duration: TimeInterval, difficulty: BeatMap.Difficulty) -> BeatMap {
        var pattern: [TimeInterval] = []
        let beatInterval: TimeInterval = 60.0 / Double(bpm)
        var time: TimeInterval = beatInterval // Start at the first beat, not 0
        
        switch difficulty {
        case .easy:
            // Straight beats only
            while time < duration {
                pattern.append(time)
                time += beatInterval
            }
        case .medium:
            // Mostly straight beats with some syncopation (skip every 8th beat)
            var beatCount = 0
            while time < duration {
                beatCount += 1
                if beatCount % 8 != 0 {
                    pattern.append(time)
                }
                time += beatInterval
            }
        case .hard:
            // Fast beats with occasional double-time bursts
            var beatCount = 0
            while time < duration {
                beatCount += 1
                pattern.append(time)
                // Every 4th beat, add a syncopated half-beat
                if beatCount % 4 == 0 && time + beatInterval / 2 < duration {
                    pattern.append(time + beatInterval / 2)
                }
                time += beatInterval
            }
            pattern.sort()
        }
        
        return BeatMap(name: name, bpm: bpm, duration: duration, difficulty: difficulty, beatPattern: pattern)
    }
    
    // MARK: - Game Control
    
    func selectTrack(_ track: BeatMap) {
        selectedTrack = track
        resetScoring()
    }
    
    func startGame() {
        guard let track = selectedTrack else { return }
        resetScoring()
        timeRemaining = track.duration
        
        // Start countdown: 3, 2, 1, GO!
        var count = 3
        gameState = .countdown(count)
        
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            count -= 1
            if count > 0 {
                self.gameState = .countdown(count)
                // Play tick sound for countdown
                AudioServicesPlaySystemSound(1104) // tock sound
            } else {
                timer.invalidate()
                self.beginPlaying()
            }
        }
    }
    
    func stopGame() {
        gameTimer?.invalidate()
        beatTimer?.invalidate()
        countdownTimer?.invalidate()
        removeJumpObserver()
        gameState = .idle
    }
    
    // MARK: - Internal Game Loop
    
    private func beginPlaying() {
        guard let track = selectedTrack else { return }
        gameState = .playing
        gameStartTime = Date()
        
        // Listen for jumps
        setupJumpObserver()
        
        // Main game timer (update progress every 50ms for smooth UI)
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self, let start = self.gameStartTime else { timer.invalidate(); return }
            
            let elapsed = Date().timeIntervalSince(start)
            self.progress = min(elapsed / track.duration, 1.0)
            self.timeRemaining = max(track.duration - elapsed, 0)
            
            // Update current beat index
            let newIndex = track.beatPattern.lastIndex(where: { $0 <= elapsed }) ?? -1
            if newIndex + 1 != self.currentBeatIndex {
                self.currentBeatIndex = newIndex + 1
            }
            
            // Check for missed beats (beats that are > goodThreshold seconds in the past)
            for (i, beatTime) in track.beatPattern.enumerated() {
                if !self.processedBeats.contains(i) && !self.hitBeats.contains(i) {
                    if elapsed - beatTime > self.goodThreshold {
                        // This beat was missed
                        self.processedBeats.insert(i)
                        self.missCount += 1
                        self.combo = 0
                        self.lastHitQuality = .miss
                    }
                }
            }
            
            // End game when duration is reached
            if elapsed >= track.duration {
                self.finishGame()
            }
        }
        
        // Beat sound timer - play a tick on each beat
        var nextBeatIndex = 0
        beatTimer?.invalidate()
        beatTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] timer in
            guard let self = self, let start = self.gameStartTime else { timer.invalidate(); return }
            let elapsed = Date().timeIntervalSince(start)
            
            if nextBeatIndex < track.beatPattern.count && elapsed >= track.beatPattern[nextBeatIndex] {
                // Play tick sound
                AudioServicesPlaySystemSound(1057) // subtle tick
                nextBeatIndex += 1
            }
            
            if elapsed >= track.duration {
                timer.invalidate()
            }
        }
    }
    
    private func finishGame() {
        gameTimer?.invalidate()
        beatTimer?.invalidate()
        removeJumpObserver()
        
        // Mark any remaining unprocessed beats as missed
        if let track = selectedTrack {
            for i in 0..<track.beatPattern.count {
                if !processedBeats.contains(i) && !hitBeats.contains(i) {
                    missCount += 1
                }
            }
        }
        
        gameState = .finished
        
        // Post notification for achievement checking
        NotificationCenter.default.post(
            name: .didFinishRhythmGame,
            object: nil,
            userInfo: [
                "grade": finalGrade,
                "score": score,
                "perfectPercent": perfectPercent
            ]
        )
    }
    
    // MARK: - Jump Handling
    
    private func setupJumpObserver() {
        jumpObserver = NotificationCenter.default.addObserver(
            forName: .didRegisterJump,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleJumpDuringGame()
        }
    }
    
    private func removeJumpObserver() {
        if let observer = jumpObserver {
            NotificationCenter.default.removeObserver(observer)
            jumpObserver = nil
        }
    }
    
    private func handleJumpDuringGame() {
        guard gameState == .playing,
              let track = selectedTrack,
              let start = gameStartTime else { return }
        
        let elapsed = Date().timeIntervalSince(start)
        
        // Find the closest beat that hasn't been hit yet
        var closestIndex: Int? = nil
        var closestDistance: TimeInterval = .greatestFiniteMagnitude
        
        for (i, beatTime) in track.beatPattern.enumerated() {
            if hitBeats.contains(i) || processedBeats.contains(i) { continue }
            let distance = abs(elapsed - beatTime)
            if distance < closestDistance {
                closestDistance = distance
                closestIndex = i
            }
        }
        
        guard let beatIndex = closestIndex else { return }
        
        // Score the hit
        if closestDistance < perfectThreshold {
            // Perfect
            hitBeats.insert(beatIndex)
            processedBeats.insert(beatIndex)
            perfectCount += 1
            combo += 1
            maxCombo = max(maxCombo, combo)
            score += 100 * combo
            lastHitQuality = .perfect
        } else if closestDistance < goodThreshold {
            // Good
            hitBeats.insert(beatIndex)
            processedBeats.insert(beatIndex)
            goodCount += 1
            combo += 1
            maxCombo = max(maxCombo, combo)
            score += 50 * combo
            lastHitQuality = .good
        }
        // If distance > goodThreshold, don't count it (jump outside any beat window)
    }
    
    // MARK: - Scoring Helpers
    
    var totalBeats: Int {
        selectedTrack?.beatPattern.count ?? 0
    }
    
    var perfectPercent: Double {
        guard totalBeats > 0 else { return 0 }
        return Double(perfectCount) / Double(totalBeats) * 100
    }
    
    var finalGrade: String {
        let pct = perfectPercent
        if pct > 90 { return "S" }
        if pct > 70 { return "A" }
        if pct > 50 { return "B" }
        if pct > 30 { return "C" }
        return "D"
    }
    
    var gradeDescription: String {
        switch finalGrade {
        case "S": return "完美演出！"
        case "A": return "非常出色！"
        case "B": return "表现不错！"
        case "C": return "继续加油！"
        default: return "多多练习！"
        }
    }
    
    // MARK: - Reset
    
    private func resetScoring() {
        perfectCount = 0
        goodCount = 0
        missCount = 0
        score = 0
        combo = 0
        maxCombo = 0
        currentBeatIndex = 0
        progress = 0
        timeRemaining = 0
        lastHitQuality = nil
        processedBeats.removeAll()
        hitBeats.removeAll()
    }
}

// MARK: - Notification

extension Notification.Name {
    static let didFinishRhythmGame = Notification.Name("didFinishRhythmGame")
}
