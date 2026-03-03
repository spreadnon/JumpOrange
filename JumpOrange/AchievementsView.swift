import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject var achievementManager: AchievementManager
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary header
                    summaryHeader
                    
                    // Achievement categories
                    ForEach(Achievement.AchievementCategory.allCases, id: \.rawValue) { category in
                        achievementSection(for: category)
                    }
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
            .navigationTitle("成就 🏆")
        }
    }
    
    // MARK: - Summary Header
    
    private var summaryHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            
            Text("\(achievementManager.unlockedCount) / \(achievementManager.totalCount)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text("成就已解锁")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange.opacity(0.15))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(
                            width: achievementManager.totalCount > 0
                                ? geo.size.width * CGFloat(achievementManager.unlockedCount) / CGFloat(achievementManager.totalCount)
                                : 0,
                            height: 8
                        )
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 40)
        }
        .padding(.top, 10)
        .padding(.bottom, 5)
    }
    
    // MARK: - Category Section
    
    private func achievementSection(for category: Achievement.AchievementCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text(category.rawValue)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                let categoryAchievements = achievementManager.achievements(for: category)
                let unlocked = categoryAchievements.filter { $0.isUnlocked }.count
                Text("\(unlocked)/\(categoryAchievements.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(UIColor.tertiarySystemFill))
                    )
            }
            .padding(.horizontal)
            
            // Achievement grid
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(achievementManager.achievements(for: category)) { achievement in
                    achievementCard(achievement)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Achievement Card
    
    private func achievementCard(_ achievement: Achievement) -> some View {
        VStack(spacing: 8) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        achievement.isUnlocked
                            ? LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 52, height: 52)
                
                Image(systemName: achievement.icon)
                    .font(.title3)
                    .foregroundColor(achievement.isUnlocked ? .white : .gray)
            }
            
            // Title
            Text(achievement.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                .lineLimit(1)
            
            // Description
            Text(achievement.description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Unlock date
            if achievement.isUnlocked, let date = achievement.unlockedDate {
                Text(formatDate(date))
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .opacity(achievement.isUnlocked ? 1.0 : 0.6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    achievement.isUnlocked ? Color.orange.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

#Preview {
    AchievementsView()
        .environmentObject(AchievementManager())
}
