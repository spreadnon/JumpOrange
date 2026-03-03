import Foundation
import CoreMotion
import Combine
import UIKit
import AVFoundation

class MotionManager: NSObject, ObservableObject {
    private let headphoneMotionManager = CMHeadphoneMotionManager()
    private var motionTimer: Timer?
    
    @Published var jumpCount: Int = 0
    @Published var isHeadphonesConnected: Bool = false
    @Published var isTracking: Bool = false
    
    // Session timer
    @Published var elapsedTime: TimeInterval = 0
    private var startTime: Date?
    private var sessionTimer: Timer?
    
    // Jumps per minute (displayed as JPS – jumps per second would be tiny, so we use per-minute)
    @Published var jumpsPerMinute: Double = 0
    
    // Configurable thresholds
    var jumpThreshold: Double = 1.2
    let cooldownInterval: TimeInterval = 0.3
    
    private var lastJumpTime: Date = Date.distantPast
    
    // Exponential moving average (EMA) low-pass filter
    private let emaAlpha: Double = 0.3 // Smoothing factor (0 = fully smooth, 1 = no filter)
    private var filteredAcceleration: Double = 0.0
    
    // Watchdog to ensure motion data is still arriving
    private var lastMotionTime: Date = Date.distantPast
    private var connectionWatchdog: Timer?
    
    // Recent jump timestamps for JPS calculation
    private var recentJumpTimestamps: [Date] = []
    
    override init() {
        super.init()
        headphoneMotionManager.delegate = self
        startContinuousMotionUpdates()
    }
    
    private func startContinuousMotionUpdates() {
        guard headphoneMotionManager.isDeviceMotionAvailable else {
            self.isHeadphonesConnected = false
            return
        }
        
        headphoneMotionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let self = self else { return }
            
            if let motion = motion, error == nil {
                self.lastMotionTime = Date()
                if !self.isHeadphonesConnected {
                    self.isHeadphonesConnected = true
                }
                
                // Only process jumps if tracking is active
                if self.isTracking {
                    self.processMotion(motion)
                }
            }
        }
        
        // Watchdog timer: If we don't receive motion updates for 2 seconds, assume disconnected
        connectionWatchdog?.invalidate()
        connectionWatchdog = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let silenceDuration = Date().timeIntervalSince(self.lastMotionTime)
            if silenceDuration > 2.0 {
                if self.isHeadphonesConnected {
                    self.isHeadphonesConnected = false
                    if self.isTracking {
                        self.stopTracking()
                    }
                }
            } else if silenceDuration < 1.0 && !self.isHeadphonesConnected {
                self.isHeadphonesConnected = true
            }
        }
    }
    
    // MARK: - Tracking Controls
    
    func startTracking() {
        if isHeadphonesConnected {
            isTracking = true
            startTime = Date()
            elapsedTime = 0
            recentJumpTimestamps.removeAll()
            jumpsPerMinute = 0
            startSessionTimer()
        }
    }
    
    func stopTracking() {
        isTracking = false
        stopSessionTimer()
    }
    
    func resetCount() {
        jumpCount = 0
        elapsedTime = 0
        jumpsPerMinute = 0
        startTime = nil
        recentJumpTimestamps.removeAll()
        filteredAcceleration = 0.0
        stopSessionTimer()
    }
    
    // MARK: - Session Timer
    
    private func startSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime else { return }
            self.elapsedTime = Date().timeIntervalSince(start)
            self.updateJumpsPerMinute()
        }
    }
    
    private func stopSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }
    
    // MARK: - JPS Calculation
    
    private func updateJumpsPerMinute() {
        // Calculate based on jumps in the last 60 seconds
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)
        recentJumpTimestamps = recentJumpTimestamps.filter { $0 > oneMinuteAgo }
        
        if elapsedTime > 0 {
            let window = min(elapsedTime, 60.0)
            if window > 0 {
                jumpsPerMinute = Double(recentJumpTimestamps.count) / (window / 60.0)
            }
        }
    }
    
    // MARK: - Motion Processing
    
    private func processMotion(_ motion: CMDeviceMotion) {
        let userAcc = motion.userAcceleration
        
        // Calculate the total magnitude of acceleration (orientation-independent)
        let rawMagnitude = sqrt(pow(userAcc.x, 2) + pow(userAcc.y, 2) + pow(userAcc.z, 2))
        
        // Apply exponential moving average (EMA) low-pass filter
        // This smooths out high-frequency noise while preserving genuine jump peaks
        filteredAcceleration = emaAlpha * rawMagnitude + (1 - emaAlpha) * filteredAcceleration
        
        if filteredAcceleration > jumpThreshold {
            let now = Date()
            if now.timeIntervalSince(lastJumpTime) > cooldownInterval {
                registerJump()
                lastJumpTime = now
            }
        }
    }
    
    private func registerJump() {
        DispatchQueue.main.async {
            self.jumpCount += 1
            self.recentJumpTimestamps.append(Date())
            self.triggerHapticFeedback()
            NotificationCenter.default.post(name: .didRegisterJump, object: nil, userInfo: ["count": self.jumpCount])
        }
    }
    
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // MARK: - Formatted Helpers
    
    /// Returns elapsed time as "MM:SS" string
    var formattedElapsedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension MotionManager: CMHeadphoneMotionManagerDelegate {
    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        DispatchQueue.main.async {
            self.startContinuousMotionUpdates()
        }
    }
    
    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        DispatchQueue.main.async {
            self.isHeadphonesConnected = false
            self.stopTracking()
        }
    }
}

extension Notification.Name {
    static let didRegisterJump = Notification.Name("didRegisterJump")
}
