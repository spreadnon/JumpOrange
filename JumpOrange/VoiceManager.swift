import Foundation
import AVFoundation

class VoiceManager: ObservableObject {
    static let shared = VoiceManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    // Configurable
    @Published var interval: Int = 10
    @Published var isEnabled: Bool = true
    
    // Voice preferences
    enum VoiceStyle: String, CaseIterable, Identifiable {
        case standard = "Standard"
        case mechanical = "Mechanical"
        case cartoon = "Cartoon"
        
        var id: String { self.rawValue }
    }
    
    @Published var selectedVoiceStyle: VoiceStyle = .standard
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleJump(_:)), name: .didRegisterJump, object: nil)
    }
    
    @objc private func handleJump(_ notification: Notification) {
        guard isEnabled, let userInfo = notification.userInfo, let jumpCount = userInfo["count"] as? Int else { return }
        
        if jumpCount > 0 && jumpCount % interval == 0 {
            speak(number: jumpCount)
        }
    }
    
    func speak(number: Int) {
        let utterance = AVSpeechUtterance(string: "\(number)")
        applyStyle(to: utterance)
        synthesizer.speak(utterance)
    }
    
    func speakGoalReached() {
        guard isEnabled else { return }
        speakText("恭喜你！目标达成！太棒了！")
    }
    
    /// Speak rhythm game results
    func speakRhythmResults(grade: String, score: Int) {
        guard isEnabled else { return }
        let gradeText: String
        switch grade {
        case "S":
            gradeText = "完美表现！你获得了S评级！得分\(score)分！"
        case "A":
            gradeText = "非常棒！你获得了A评级！得分\(score)分！"
        case "B":
            gradeText = "不错！你获得了B评级！得分\(score)分！"
        case "C":
            gradeText = "还可以！你获得了C评级，继续加油！"
        default:
            gradeText = "你获得了\(grade)评级，多练习会更好的！"
        }
        speakText(gradeText)
    }
    
    /// Speak challenge completion
    func speakChallengeCompleted(title: String) {
        guard isEnabled else { return }
        speakText("恭喜！每日挑战「\(title)」完成！")
    }
    
    /// Speak achievement unlocked
    func speakAchievementUnlocked(title: String) {
        guard isEnabled else { return }
        speakText("成就解锁！\(title)！")
    }
    
    // MARK: - Private
    
    private func speakText(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        applyStyle(to: utterance)
        synthesizer.speak(utterance)
    }
    
    private func applyStyle(to utterance: AVSpeechUtterance) {
        switch selectedVoiceStyle {
        case .standard:
            utterance.pitchMultiplier = 1.0
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        case .mechanical:
            utterance.pitchMultiplier = 0.5
            utterance.rate = 0.4
        case .cartoon:
            utterance.pitchMultiplier = 2.0
            utterance.rate = 0.6
        }
        
        // Use Chinese voice
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
    }
}
