import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var storageManager: StorageManager
    @EnvironmentObject var voiceManager: VoiceManager
    @EnvironmentObject var motionManager: MotionManager
    
    @State private var showResetConfirmation: Bool = false
    @State private var showResetDone: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("目标")) {
                    Stepper(value: $storageManager.dailyGoal, in: 10...10000, step: 50) {
                        HStack {
                            Text("每日目标")
                            Spacer()
                            Text("\(storageManager.dailyGoal) 次")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("语音反馈")) {
                    Toggle("启用语音", isOn: $voiceManager.isEnabled)
                    
                    if voiceManager.isEnabled {
                        Picker("语音风格", selection: $voiceManager.selectedVoiceStyle) {
                            Text("标准").tag(VoiceManager.VoiceStyle.standard)
                            Text("机械").tag(VoiceManager.VoiceStyle.mechanical)
                            Text("卡通").tag(VoiceManager.VoiceStyle.cartoon)
                        }
                        
                        Picker("播报间隔", selection: $voiceManager.interval) {
                            Text("每 10 次").tag(10)
                            Text("每 50 次").tag(50)
                            Text("每 100 次").tag(100)
                        }
                    }
                }
                
                Section(header: Text("传感器调节"), footer: Text("如果跳跃检测不准确，请调整灵敏度。低灵敏度需要更大的跳跃动作。")) {
                    Picker("灵敏度", selection: Binding(
                        get: { storageManager.jumpSensitivity },
                        set: { newValue in
                            storageManager.jumpSensitivity = newValue
                            updateThreshold(for: newValue)
                        }
                    )) {
                        Text("低").tag(0)
                        Text("中").tag(1)
                        Text("高").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("数据管理")) {
                    Button(role: .destructive, action: {
                        showResetConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("重置所有数据")
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("关于")) {
                    HStack {
                        Text("应用名称")
                        Spacer()
                        Text("JumpOrange 🍊")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("累计跳跃")
                        Spacer()
                        Text("\(storageManager.totalAllTimeJumps) 次")
                            .foregroundColor(.orange)
                    }
                    
                    HStack {
                        Text("最长连续")
                        Spacer()
                        Text("\(storageManager.longestStreak) 天")
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("设置 ⚙️")
            .onAppear {
                updateThreshold(for: storageManager.jumpSensitivity)
                
                if let style = VoiceManager.VoiceStyle(rawValue: storageManager.voiceStyleString) {
                    voiceManager.selectedVoiceStyle = style
                }
                voiceManager.interval = storageManager.voiceInterval
            }
            .onChange(of: voiceManager.selectedVoiceStyle) { newValue in
                storageManager.voiceStyleString = newValue.rawValue
            }
            .onChange(of: voiceManager.interval) { newValue in
                storageManager.voiceInterval = newValue
            }
            .alert("确认重置", isPresented: $showResetConfirmation) {
                Button("取消", role: .cancel) { }
                Button("重置", role: .destructive) {
                    storageManager.resetAllData()
                    showResetDone = true
                }
            } message: {
                Text("这将清除所有跳跃记录、成就和设置。此操作无法撤销。")
            }
            .alert("已重置", isPresented: $showResetDone) {
                Button("好的") { }
            } message: {
                Text("所有数据已成功重置。")
            }
        }
    }
    
    private func updateThreshold(for sensitivity: Int) {
        switch sensitivity {
        case 0:
            motionManager.jumpThreshold = 1.6
        case 1:
            motionManager.jumpThreshold = 1.2
        case 2:
            motionManager.jumpThreshold = 0.8
        default:
            motionManager.jumpThreshold = 1.2
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(StorageManager())
        .environmentObject(VoiceManager.shared)
        .environmentObject(MotionManager())
}
