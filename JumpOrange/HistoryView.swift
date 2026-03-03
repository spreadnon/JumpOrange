import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var storageManager: StorageManager
    
    var body: some View {
        List {
            Section(header: Text("今日概览")) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("总跳跃")
                            .font(.headline)
                        Text("\(storageManager.getTodayTotal())")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                            .bold()
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("预估热量")
                            .font(.headline)
                        Text(String(format: "%.1f 千卡", Double(storageManager.getTodayTotal()) * 0.14))
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 8)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("连续天数")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(storageManager.currentStreak) 天")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("累计跳跃")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(storageManager.totalAllTimeJumps)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 4)
            }
            
            if !storageManager.dailyRecords.isEmpty {
                Section(header: Text("7日趋势")) {
                    if #available(iOS 16.0, *) {
                        Chart {
                            ForEach(storageManager.dailyRecords.prefix(7).reversed()) { record in
                                BarMark(
                                    x: .value("日期", dateStringToShort(record.dateString)),
                                    y: .value("跳跃", record.totalJumps)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.orange, .red],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .cornerRadius(4)
                            }
                        }
                        .frame(height: 200)
                        .padding(.vertical)
                    } else {
                        // Fallback simple bar chart for iOS 15
                        simpleBarChart
                    }
                }
            }
            
            Section(header: Text("历史记录")) {
                if storageManager.dailyRecords.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "figure.jump")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("还没有跳跃记录")
                                .foregroundColor(.secondary)
                            Text("开始跳跃吧！")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                } else {
                    ForEach(storageManager.dailyRecords) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formatDateString(record.dateString))
                                    .font(.subheadline)
                                Text("\(record.sessions.count) 次训练")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(record.totalJumps) 次")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                Text(String(format: "%.0f 千卡", Double(record.totalJumps) * 0.14))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("历史记录")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Simple bar chart fallback for iOS 15
    
    private var simpleBarChart: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(storageManager.dailyRecords.prefix(7).reversed()) { record in
                VStack(spacing: 4) {
                    Text("\(record.totalJumps)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange)
                        .frame(height: barHeight(for: record.totalJumps))
                    
                    Text(dateStringToShort(record.dateString))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 180)
        .padding(.vertical)
    }
    
    private func barHeight(for jumps: Int) -> CGFloat {
        let maxJumps = storageManager.dailyRecords.prefix(7).map { $0.totalJumps }.max() ?? 1
        let ratio = CGFloat(jumps) / CGFloat(max(maxJumps, 1))
        return max(ratio * 140, 4)
    }
    
    // MARK: - Helpers
    
    private func dateStringToShort(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
        return dateStr
    }
    
    private func formatDateString(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            formatter.dateFormat = "MM月dd日"
            return formatter.string(from: date)
        }
        return dateStr
    }
}

#Preview {
    NavigationView {
        HistoryView()
            .environmentObject(StorageManager())
    }
}
