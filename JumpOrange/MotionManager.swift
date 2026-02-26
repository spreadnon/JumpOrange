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
    
    // Configurable thresholds
    var jumpThreshold: Double = 1.2
    let cooldownInterval: TimeInterval = 0.3
    
    private var lastJumpTime: Date = Date.distantPast
    
    // Watchdog to ensure motion data is still arriving
    private var lastMotionTime: Date = Date.distantPast
    private var connectionWatchdog: Timer?
    
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
        
        // Watchdog timer: If we don't receive motion updates for 2 seconds, assume disconnected/taken off.
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
    
    func startTracking() {
        if isHeadphonesConnected {
            isTracking = true
        }
    }
    
    func stopTracking() {
        isTracking = false
    }
    
    func resetCount() {
        jumpCount = 0
    }
    
    private func processMotion(_ motion: CMDeviceMotion) {
        let userAcc = motion.userAcceleration
        
        // Calculate the total magnitude of acceleration to be independent of head orientation
        let accelerationMagnitude = sqrt(pow(userAcc.x, 2) + pow(userAcc.y, 2) + pow(userAcc.z, 2))
        
        if accelerationMagnitude > jumpThreshold {
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
            self.triggerHapticFeedback()
            NotificationCenter.default.post(name: .didRegisterJump, object: nil, userInfo: ["count": self.jumpCount])
        }
    }
    
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

extension MotionManager: CMHeadphoneMotionManagerDelegate {
    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        // Re-evaluate continuous updates upon actual bluetooth connection
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
