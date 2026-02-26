import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var storageManager: StorageManager
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Today's Summary")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Jumps")
                                .font(.headline)
                            Text("\(storageManager.getTodayTotal())")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                                .bold()
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Est. Calories")
                                .font(.headline)
                            Text(String(format: NSLocalizedString("%.1f kcal", comment: ""), Double(storageManager.getTodayTotal()) * 0.14))
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                if !storageManager.dailyRecords.isEmpty {
                    Section(header: Text("7-Day Trend")) {
                        // iOS 16+ Charts framework
                        if #available(iOS 16.0, *) {
                            Chart {
                                ForEach(storageManager.dailyRecords.prefix(7).reversed()) { record in
                                    BarMark(
                                        x: .value("Day", dateStringToShort(record.dateString)),
                                        y: .value("Jumps", record.totalJumps)
                                    )
                                    .foregroundStyle(.orange)
                                }
                            }
                            .frame(height: 200)
                            .padding(.vertical)
                        } else {
                            Text("Charts require iOS 16+")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("History")) {
                    if storageManager.dailyRecords.isEmpty {
                        Text("No jumps recorded yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(storageManager.dailyRecords) { record in
                            HStack {
                                Text(record.dateString)
                                Spacer()
                                Text(String(format: NSLocalizedString("%d jumps", comment: ""), record.totalJumps))
                                    .bold()
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("History")
        }
    }
    
    // Helper to format "yyyy-MM-dd" to "MM/dd"
    private func dateStringToShort(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
        return dateStr
    }
}

#Preview {
    HistoryView()
        .environmentObject(StorageManager())
}
