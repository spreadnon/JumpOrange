import Foundation
import AVFoundation

class VoiceManager: ObservableObject {
    static let shared = VoiceManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    // Configurable
    @Published var interval: Int = 10 // Say the number every 10 jumps
    @Published var isEnabled: Bool = true
    
    // Voice preferences
    enum VoiceStyle: String, CaseIterable, Identifiable {
        case standard = "Standard"
        case mechanical = "Mechanical"
        case cartoon = "Cartoon" // Placeholder for pitch/rate adjustments
        
        var id: String { self.rawValue }
    }
    
    @Published var selectedVoiceStyle: VoiceStyle = .standard
    
    init() {
        // Setup observer for jump counts
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
        
        // Apply voice styles (basic example using pitch and rate)
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
        
        // Optional: Ensure English or System locale depending on needs
        if let language = Locale.preferredLanguages.first {
            utterance.voice = AVSpeechSynthesisVoice(language: language)
        }
        
        synthesizer.speak(utterance)
    }
    
    func speakGoalReached() {
        guard isEnabled else { return }
        let utterance = AVSpeechUtterance(string: NSLocalizedString("Goal Reached! Great Job!", comment: ""))
        if let language = Locale.preferredLanguages.first {
            utterance.voice = AVSpeechSynthesisVoice(language: language)
        }
        synthesizer.speak(utterance)
    }
}
