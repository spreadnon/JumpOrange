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
    
    // Maintain a separate state to handle background checking versus active tracking.
    private var isCheckingStatus: Bool = false
    
    // Configurable thresholds
    var jumpThreshold: Double = 1.2
    let cooldownInterval: TimeInterval = 0.3
    
    private var lastJumpTime: Date = Date.distantPast
    
    override init() {
        super.init()
        headphoneMotionManager.delegate = self
        startStatusPolling()
    }
    
    // Periodically poll for device motion when not actively tracking
    private func startStatusPolling() {
        // Poll every 2 seconds
        motionTimer?.invalidate()
        motionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkHeadphoneStatus()
        }
    }
    
    func startTracking() {
        guard headphoneMotionManager.isDeviceMotionAvailable else {
            print("Headphone motion is not available")
            return
        }
        
        isTracking = true
        // If we were just checking status in the background, we don't need to restart updates, 
        // just process them differently. But safely, reset updates.
        headphoneMotionManager.stopDeviceMotionUpdates()
        motionTimer?.invalidate()
        
        headphoneMotionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let self = self else { return }
            
            // If we receive data, then headphones are definitely connected and worn.
            if !self.isHeadphonesConnected {
                self.isHeadphonesConnected = true
            }
            
            if let motion = motion, error == nil {
                self.processMotion(motion)
            }
        }
    }
    
    func stopTracking() {
        isTracking = false
        headphoneMotionManager.stopDeviceMotionUpdates()
        startStatusPolling()
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
    
    private func checkHeadphoneStatus() {
        // Without active tracking, we can't reliably know if AirPods are worn based on `isDeviceMotionAvailable` alone.
        // We will briefly try to start motion updates to see if we get data, then immediately stop to save battery,
        // or just rely on the first callback.
        
        guard !isTracking else { return }
        guard headphoneMotionManager.isDeviceMotionAvailable else {
            if self.isHeadphonesConnected {
                DispatchQueue.main.async { self.isHeadphonesConnected = false }
            }
            return
        }
        
        isCheckingStatus = true
        
        headphoneMotionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // If we receive any reliable motion data
                if motion != nil && error == nil {
                    if !self.isHeadphonesConnected {
                        self.isHeadphonesConnected = true
                    }
                } else {
                    if self.isHeadphonesConnected {
                        self.isHeadphonesConnected = false
                    }
                }
            }
            
            // Stop immediately after checking to avoid draining battery when not explicitly tracking
            self.headphoneMotionManager.stopDeviceMotionUpdates()
            self.isCheckingStatus = false
        }
    }
    
    @objc private func routeChanged(notification: Notification) {
        // Fallback or additional handling if needed, but CoreMotion delegation and active updates are more reliable for AirPods.
    }
}

extension MotionManager: CMHeadphoneMotionManagerDelegate {
        func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
            DispatchQueue.main.async {
                self.isHeadphonesConnected = true
            }
        }
        
        func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
            DispatchQueue.main.async {
                self.isHeadphonesConnected = false
                if self.isTracking {
                    self.stopTracking() // Will drop to status checking
                }
            }
        }
    }

extension Notification.Name {
    static let didRegisterJump = Notification.Name("didRegisterJump")
}
