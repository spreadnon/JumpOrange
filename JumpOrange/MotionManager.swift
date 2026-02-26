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
    
    override init() {
        super.init()
        headphoneMotionManager.delegate = self
        checkHeadphoneStatus()
    }
    
    func startTracking() {
        guard headphoneMotionManager.isDeviceMotionAvailable else {
            print("Headphone motion is not available")
            return
        }
        
        isTracking = true
        headphoneMotionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let self = self, let motion = motion, error == nil else { return }
            self.processMotion(motion)
        }
    }
    
    func stopTracking() {
        headphoneMotionManager.stopDeviceMotionUpdates()
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
    
    private func checkHeadphoneStatus() {
        let session = AVAudioSession.sharedInstance()
        let isConnected = session.currentRoute.outputs.contains {
            $0.portType == .bluetoothA2DP || $0.portType == .bluetoothLE || $0.portType == .headphones
        }
        self.isHeadphonesConnected = isConnected
        
        NotificationCenter.default.addObserver(self, selector: #selector(routeChanged), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    @objc private func routeChanged(notification: Notification) {
        let session = AVAudioSession.sharedInstance()
        let isConnected = session.currentRoute.outputs.contains {
            $0.portType == .bluetoothA2DP || $0.portType == .bluetoothLE || $0.portType == .headphones
        }
        DispatchQueue.main.async {
            self.isHeadphonesConnected = isConnected
            if !isConnected && self.isTracking {
                self.stopTracking()
            }
        }
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
            self.stopTracking()
        }
    }
}

extension Notification.Name {
    static let didRegisterJump = Notification.Name("didRegisterJump")
}
