import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var motionManager: MotionManager
    @EnvironmentObject var storageManager: StorageManager
    @EnvironmentObject var voiceManager: VoiceManager
    
    @State private var showMedal: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Status Indicator
                HStack {
                    Circle()
                        .fill(motionManager.isHeadphonesConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(motionManager.isHeadphonesConnected ? "AirPods Connected" : "Searching for AirPods...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                Spacer()
                
                // LCD Counter
                VStack(spacing: 10) {
                    Text("\(motionManager.jumpCount)")
                        .font(.system(size: 100, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    
                    Text("JUMPS")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .tracking(2)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                )
                .padding(.horizontal, 40)
                
                // Goal Progress
                VStack {
                    ProgressView(value: Double(motionManager.jumpCount), total: Double(storageManager.dailyGoal))
                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                        .padding(.horizontal, 40)
                    
                    Text(String(format: NSLocalizedString("%d / %d Today", comment: ""), motionManager.jumpCount, storageManager.dailyGoal))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: 40) {
                    Button(action: {
                        motionManager.resetCount()
                    }) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.gray)
                    }
                    
                    Button(action: {
                        if motionManager.isTracking {
                            motionManager.stopTracking()
                            // Save session when stopping
                            storageManager.saveSession(jumps: motionManager.jumpCount, duration: 0) // Duration needs proper tracking
                        } else {
                            motionManager.startTracking()
                        }
                    }) {
                        Image(systemName: motionManager.isTracking ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.orange)
                            .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("JumpOrange")
            .onReceive(motionManager.$jumpCount) { count in
                if count == storageManager.dailyGoal && count > 0 && !showMedal {
                    showMedal = true
                    voiceManager.speakGoalReached()
                }
            }
            .alert(isPresented: $showMedal) {
                Alert(
                    title: Text("🎉 Goal Reached! 🎉"),
                    message: Text(String(format: NSLocalizedString("You completed your daily goal of %d jumps!", comment: ""), storageManager.dailyGoal)),
                    dismissButton: .default(Text("Awesome!"))
                )
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(MotionManager())
        .environmentObject(StorageManager())
        .environmentObject(VoiceManager.shared)
}
