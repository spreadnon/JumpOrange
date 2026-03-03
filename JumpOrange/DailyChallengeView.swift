import SwiftUI

struct DailyChallengeView: View {
    @EnvironmentObject var dailyChallengeManager: DailyChallengeManager
    @EnvironmentObject var storageManager: StorageManager
    
    @State private var showCheckmark: Bool = false
    @State private var checkmarkScale: CGFloat = 0.1
    @State private var confettiOpacity: Double = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Today's challenge
                    todayChallengeCard
                    
                    // Completion stats
                    completionStats
                    
                    // Week history
                    weekHistorySection
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
            .navigationTitle("每日挑战 ⚡")
            .onReceive(dailyChallengeManager.$showCompletionAnimation) { show in
                if show {
                    triggerCompletionAnimation()
                }
            }
        }
    }
    
    // MARK: - Today's Challenge
    
    private var todayChallengeCard: some View {
        VStack(spacing: 16) {
            if let challenge = dailyChallengeManager.todayChallenge {
                // Header
                HStack {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 50, height: 50)
                        Image(systemName: challenge.type.icon)
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("今日挑战")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(challenge.title)
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    if challenge.isCompleted {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
                
                // Description
                Text(challenge.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Progress
                VStack(spacing: 8) {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.orange.opacity(0.15))
                                .frame(height: 16)
                            
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    challenge.isCompleted ?
                                    LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing) :
                                    LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: geo.size.width * CGFloat(challenge.progress), height: 16)
                                .animation(.spring(), value: challenge.progress)
                        }
                    }
                    .frame(height: 16)
                    
                    HStack {
                        Text("进度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(challenge.currentValue) / \(challenge.target)")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(challenge.isCompleted ? .green : .orange)
                    }
                }
                
                // Completion celebration overlay
                if showCheckmark {
                    ZStack {
                        // Confetti-like dots
                        ForEach(0..<12, id: \.self) { i in
                            Circle()
                                .fill(confettiColor(i))
                                .frame(width: 8, height: 8)
                                .offset(x: confettiOffset(i).x, y: confettiOffset(i).y)
                                .opacity(confettiOpacity)
                        }
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                            .scaleEffect(checkmarkScale)
                    }
                    .frame(height: 80)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("今日暂无挑战")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 30)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.orange.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    // MARK: - Stats
    
    private var completionStats: some View {
        HStack(spacing: 16) {
            statBadge(
                icon: "checkmark.circle.fill",
                value: "\(dailyChallengeManager.completedCount)",
                label: "已完成",
                color: .green
            )
            
            statBadge(
                icon: "flame.fill",
                value: "\(storageManager.currentStreak)",
                label: "连续天数",
                color: .orange
            )
            
            statBadge(
                icon: "star.fill",
                value: "\(storageManager.totalAllTimeJumps)",
                label: "总跳跃",
                color: .yellow
            )
        }
        .padding(.horizontal)
    }
    
    private func statBadge(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
    
    // MARK: - Week History
    
    private var weekHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本周挑战")
                .font(.headline)
                .padding(.horizontal)
            
            if dailyChallengeManager.weekChallenges.isEmpty {
                Text("暂无历史记录")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(dailyChallengeManager.weekChallenges) { challenge in
                    HStack(spacing: 12) {
                        // Date
                        VStack {
                            Text(shortDate(challenge.dateString))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 50)
                        
                        // Icon
                        Image(systemName: challenge.type.icon)
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        // Info
                        VStack(alignment: .leading, spacing: 2) {
                            Text(challenge.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(challenge.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Status
                        Image(systemName: challenge.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(challenge.isCompleted ? .green : .gray)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Animation
    
    private func triggerCompletionAnimation() {
        showCheckmark = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
            checkmarkScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.6)) {
            confettiOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.3)) {
                showCheckmark = false
                checkmarkScale = 0.1
                confettiOpacity = 0
            }
            dailyChallengeManager.showCompletionAnimation = false
        }
    }
    
    private func confettiColor(_ index: Int) -> Color {
        let colors: [Color] = [.orange, .yellow, .green, .red, .blue, .pink]
        return colors[index % colors.count]
    }
    
    private func confettiOffset(_ index: Int) -> CGPoint {
        let angle = CGFloat(index) * (360.0 / 12.0) * .pi / 180.0
        let radius: CGFloat = 50
        return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
    }
    
    // MARK: - Helpers
    
    private func shortDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
        return dateString
    }
}

#Preview {
    DailyChallengeView()
        .environmentObject(DailyChallengeManager())
        .environmentObject(StorageManager())
}
