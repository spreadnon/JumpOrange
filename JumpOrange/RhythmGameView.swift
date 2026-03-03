import SwiftUI

struct RhythmGameView: View {
    @EnvironmentObject var motionManager: MotionManager
    @EnvironmentObject var voiceManager: VoiceManager
    @EnvironmentObject var achievementManager: AchievementManager
    @StateObject private var rhythmManager = RhythmManager()
    
    @State private var beatPulse: CGFloat = 1.0
    @State private var showResults: Bool = false
    @State private var gradeScale: CGFloat = 0.1
    
    var body: some View {
        NavigationView {
            Group {
                switch rhythmManager.gameState {
                case .idle:
                    trackSelectionView
                case .countdown(let count):
                    countdownView(count: count)
                case .playing:
                    gamePlayView
                case .finished:
                    resultsView
                }
            }
            .navigationTitle("节奏跳跃 🎵")
        }
    }
    
    // MARK: - Track Selection
    
    private var trackSelectionView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("选择曲目")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("跟着节拍跳跃，获取最高评分！")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                // Track cards
                ForEach(rhythmManager.tracks) { track in
                    Button(action: {
                        rhythmManager.selectTrack(track)
                        // Start tracking motion for rhythm game
                        if !motionManager.isTracking {
                            motionManager.startTracking()
                        }
                        rhythmManager.startGame()
                    }) {
                        trackCard(track)
                    }
                    .disabled(!motionManager.isHeadphonesConnected)
                }
                
                if !motionManager.isHeadphonesConnected {
                    HStack {
                        Image(systemName: "airpodspro")
                            .foregroundColor(.secondary)
                        Text("请先连接 AirPods 才能开始游戏")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 10)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func trackCard(_ track: BeatMap) -> some View {
        HStack(spacing: 16) {
            // Track icon
            ZStack {
                Circle()
                    .fill(difficultyGradient(track.difficulty))
                    .frame(width: 56, height: 56)
                Image(systemName: track.difficulty.icon)
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    Label("\(track.bpm) BPM", systemImage: "metronome")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(Int(track.duration))秒", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("\(track.beatPattern.count) 拍")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Difficulty badge
            Text(track.difficulty.rawValue)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(difficultyGradient(track.difficulty))
                )
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
    
    // MARK: - Countdown
    
    private func countdownView(count: Int) -> some View {
        VStack {
            Spacer()
            
            Text("\(count)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundColor(.orange)
                .scaleEffect(beatPulse)
                .animation(.easeOut(duration: 0.3), value: count)
                .onChange(of: count) { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                        beatPulse = 1.3
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.spring()) {
                            beatPulse = 1.0
                        }
                    }
                }
            
            Text("准备跳跃！")
                .font(.title2)
                .foregroundColor(.secondary)
                .padding(.top, 10)
            
            Spacer()
        }
    }
    
    // MARK: - Game Play
    
    private var gamePlayView: some View {
        VStack(spacing: 16) {
            // Score bar
            HStack {
                VStack(alignment: .leading) {
                    Text("得分")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(rhythmManager.score)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                // Combo
                if rhythmManager.combo > 1 {
                    VStack {
                        Text("连击")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("×\(rhythmManager.combo)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("剩余")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatTime(rhythmManager.timeRemaining))
                        .font(.title3)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal)
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange.opacity(0.15))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange)
                        .frame(width: geo.size.width * CGFloat(rhythmManager.progress), height: 6)
                        .animation(.linear(duration: 0.05), value: rhythmManager.progress)
                }
            }
            .frame(height: 6)
            .padding(.horizontal)
            
            Spacer()
            
            // Central beat indicator
            ZStack {
                // Outer ring
                Circle()
                    .stroke(hitQualityColor.opacity(0.3), lineWidth: 4)
                    .frame(width: 180, height: 180)
                
                // Pulsing circle
                Circle()
                    .fill(hitQualityColor.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .scaleEffect(beatPulse)
                
                // Inner circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [hitQualityColor, hitQualityColor.opacity(0.6)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(beatPulse)
                
                // Hit quality text
                if let quality = rhythmManager.lastHitQuality {
                    Text(qualityText(quality))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .onChange(of: rhythmManager.currentBeatIndex) { _ in
                // Pulse on each beat
                withAnimation(.easeOut(duration: 0.1)) {
                    beatPulse = 1.15
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        beatPulse = 1.0
                    }
                }
            }
            .onChange(of: rhythmManager.lastHitQuality.map { "\($0)" } ?? "") { _ in
                // Extra pulse on hit
                withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
                    beatPulse = 1.25
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring()) {
                        beatPulse = 1.0
                    }
                }
            }
            
            Spacer()
            
            // Hit quality counters
            HStack(spacing: 24) {
                hitCounter(label: "完美", count: rhythmManager.perfectCount, color: .green)
                hitCounter(label: "不错", count: rhythmManager.goodCount, color: .yellow)
                hitCounter(label: "失误", count: rhythmManager.missCount, color: .red)
            }
            .padding(.bottom, 10)
            
            // Stop button
            Button(action: {
                rhythmManager.stopGame()
                motionManager.stopTracking()
            }) {
                Text("结束游戏")
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .stroke(Color.red.opacity(0.5), lineWidth: 1)
                    )
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Results
    
    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)
                
                // Grade
                VStack(spacing: 8) {
                    Text(rhythmManager.finalGrade)
                        .font(.system(size: 100, weight: .bold, design: .rounded))
                        .foregroundColor(gradeColor)
                        .scaleEffect(gradeScale)
                        .onAppear {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                                gradeScale = 1.0
                            }
                            // Check achievements
                            achievementManager.checkRhythmFirst()
                            achievementManager.checkRhythmSRank(perfectPercent: rhythmManager.perfectPercent)
                            // Voice
                            voiceManager.speakRhythmResults(grade: rhythmManager.finalGrade, score: rhythmManager.score)
                        }
                    
                    Text(rhythmManager.gradeDescription)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                // Score
                VStack(spacing: 4) {
                    Text("总分")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(rhythmManager.score)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
                
                // Stats
                VStack(spacing: 12) {
                    resultRow(label: "完美", value: "\(rhythmManager.perfectCount)", color: .green)
                    resultRow(label: "不错", value: "\(rhythmManager.goodCount)", color: .yellow)
                    resultRow(label: "失误", value: "\(rhythmManager.missCount)", color: .red)
                    Divider()
                    resultRow(label: "最大连击", value: "\(rhythmManager.maxCombo)", color: .orange)
                    resultRow(label: "总拍数", value: "\(rhythmManager.totalBeats)", color: .primary)
                    resultRow(label: "完美率", value: String(format: "%.1f%%", rhythmManager.perfectPercent), color: .primary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .padding(.horizontal)
                
                // Action buttons
                HStack(spacing: 20) {
                    Button(action: {
                        gradeScale = 0.1
                        rhythmManager.startGame()
                    }) {
                        Label("再来一次", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(Color.orange)
                            )
                    }
                    
                    Button(action: {
                        gradeScale = 0.1
                        rhythmManager.stopGame()
                        motionManager.stopTracking()
                    }) {
                        Label("返回", systemImage: "chevron.left")
                            .font(.headline)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .stroke(Color.orange, lineWidth: 2)
                            )
                    }
                }
                .padding(.top, 10)
            }
        }
    }
    
    // MARK: - Helpers
    
    private var hitQualityColor: Color {
        guard let quality = rhythmManager.lastHitQuality else { return .orange }
        switch quality {
        case .perfect: return .green
        case .good: return .yellow
        case .miss: return .red
        }
    }
    
    private var gradeColor: Color {
        switch rhythmManager.finalGrade {
        case "S": return .yellow
        case "A": return .green
        case "B": return .blue
        case "C": return .orange
        default: return .gray
        }
    }
    
    private func qualityText(_ quality: HitQuality) -> String {
        switch quality {
        case .perfect: return "完美！"
        case .good: return "不错！"
        case .miss: return "失误"
        }
    }
    
    private func hitCounter(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 70)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
    
    private func resultRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func difficultyGradient(_ difficulty: BeatMap.Difficulty) -> LinearGradient {
        switch difficulty {
        case .easy:
            return LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .medium:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .hard:
            return LinearGradient(colors: [.red, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

#Preview {
    RhythmGameView()
        .environmentObject(MotionManager())
        .environmentObject(VoiceManager.shared)
        .environmentObject(AchievementManager())
}
