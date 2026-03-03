import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var motionManager: MotionManager
    @EnvironmentObject var storageManager: StorageManager
    @EnvironmentObject var voiceManager: VoiceManager
    @EnvironmentObject var dailyChallengeManager: DailyChallengeManager
    @EnvironmentObject var achievementManager: AchievementManager
    
    @State private var showMedal: Bool = false
    @State private var jumpScale: CGFloat = 1.0
    @State private var showHistory: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection status
                    connectionStatusView
                    
                    // Jump counter card
                    jumpCounterCard
                    
                    // Session stats row
                    sessionStatsRow
                    
                    // Goal progress
                    goalProgressCard
                    
                    // Daily Challenge card
                    dailyChallengeCard
                    
                    // Controls
                    controlButtons
                    
                    // History link
                    NavigationLink(destination: HistoryView()) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.orange)
                            Text("查看历史记录")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .background(
                LinearGradient(
                    colors: [Color.orange.opacity(0.05), Color(UIColor.systemBackground)],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            )
            .navigationTitle("JumpOrange 🍊")
            .onReceive(motionManager.$jumpCount) { count in
                // Animate jump counter
                if count > 0 {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        jumpScale = 1.2
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                            jumpScale = 1.0
                        }
                    }
                }
                
                // Update daily challenge progress
                let todayTotal = storageManager.getTodayTotal() + count
                dailyChallengeManager.updateProgress(todayJumps: todayTotal)
                
                // Check achievements
                let allTime = storageManager.totalAllTimeJumps + count
                achievementManager.checkMilestones(totalJumps: allTime)
                
                // Goal reached
                if count == storageManager.dailyGoal && count > 0 && !showMedal {
                    showMedal = true
                    voiceManager.speakGoalReached()
                }
            }
            .alert(isPresented: $showMedal) {
                Alert(
                    title: Text("🎉 目标达成！🎉"),
                    message: Text("你完成了今日\(storageManager.dailyGoal)次跳跃目标！"),
                    dismissButton: .default(Text("太棒了！"))
                )
            }
        }
    }
    
    // MARK: - Subviews
    
    private var connectionStatusView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(motionManager.isHeadphonesConnected ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            
            Text(motionManager.isHeadphonesConnected ? "AirPods 已连接" : "正在搜索 AirPods...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }
    
    private var jumpCounterCard: some View {
        VStack(spacing: 8) {
            Text("\(motionManager.jumpCount)")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundColor(.orange)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .scaleEffect(jumpScale)
            
            Text("跳跃次数")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.orange.opacity(0.15), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .padding(.horizontal)
    }
    
    private var sessionStatsRow: some View {
        HStack(spacing: 12) {
            // Timer
            statCard(icon: "timer", title: "时长", value: motionManager.formattedElapsedTime)
            
            // JPS (jumps per minute)
            statCard(icon: "speedometer", title: "次/分钟", value: String(format: "%.0f", motionManager.jumpsPerMinute))
            
            // Today total
            statCard(icon: "calendar", title: "今日总计", value: "\(storageManager.getTodayTotal())")
        }
        .padding(.horizontal)
    }
    
    private func statCard(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
            
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
    
    private var goalProgressCard: some View {
        VStack(spacing: 8) {
            HStack {
                Text("每日目标")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(storageManager.getTodayTotal()) / \(storageManager.dailyGoal)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.15))
                        .frame(height: 10)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * CGFloat(min(Double(storageManager.getTodayTotal()) / Double(storageManager.dailyGoal), 1.0)), height: 10)
                        .animation(.easeInOut, value: storageManager.getTodayTotal())
                }
            }
            .frame(height: 10)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    private var dailyChallengeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                Text("每日挑战")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
                if let challenge = dailyChallengeManager.todayChallenge, challenge.isCompleted {
                    Text("✅ 已完成")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            }
            
            if let challenge = dailyChallengeManager.todayChallenge {
                HStack {
                    Image(systemName: challenge.type.icon)
                        .foregroundColor(.orange.opacity(0.8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(challenge.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(challenge.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress bar
                HStack {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.orange.opacity(0.15))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(challenge.isCompleted ? Color.green : Color.orange)
                                .frame(width: geo.size.width * CGFloat(challenge.progress), height: 8)
                                .animation(.easeInOut, value: challenge.progress)
                        }
                    }
                    .frame(height: 8)
                    
                    Text("\(challenge.currentValue)/\(challenge.target)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
            } else {
                Text("今日暂无挑战")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    private var controlButtons: some View {
        HStack(spacing: 40) {
            // Reset button
            Button(action: {
                motionManager.resetCount()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .resizable()
                        .frame(width: 52, height: 52)
                        .foregroundColor(.gray)
                    Text("重置")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Play/Pause button
            Button(action: {
                if motionManager.isTracking {
                    motionManager.stopTracking()
                    storageManager.saveSession(jumps: motionManager.jumpCount, duration: motionManager.elapsedTime)
                    
                    // Check streak achievements after saving
                    achievementManager.checkStreaks(currentStreak: storageManager.currentStreak)
                } else {
                    motionManager.startTracking()
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: motionManager.isTracking ? "pause.circle.fill" : "play.circle.fill")
                        .resizable()
                        .frame(width: 72, height: 72)
                        .foregroundColor(motionManager.isHeadphonesConnected ? .orange : Color.gray.opacity(0.3))
                        .shadow(color: motionManager.isHeadphonesConnected && !motionManager.isTracking ? .orange.opacity(0.4) : .clear, radius: 10, x: 0, y: 5)
                    Text(motionManager.isTracking ? "暂停" : "开始")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(motionManager.isHeadphonesConnected ? .orange : .gray)
                }
            }
            .disabled(!motionManager.isHeadphonesConnected)
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    DashboardView()
        .environmentObject(MotionManager())
        .environmentObject(StorageManager())
        .environmentObject(VoiceManager.shared)
        .environmentObject(DailyChallengeManager())
        .environmentObject(AchievementManager())
}
