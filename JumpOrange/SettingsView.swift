import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var storageManager: StorageManager
    @EnvironmentObject var voiceManager: VoiceManager
    @EnvironmentObject var motionManager: MotionManager
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Goals")) {
                    Stepper(value: $storageManager.dailyGoal, in: 10...10000, step: 50) {
                        HStack {
                            Text("Daily Goal")
                            Spacer()
                            Text("\(storageManager.dailyGoal)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Voice Feedback")) {
                    Toggle("Enable Voice", isOn: $voiceManager.isEnabled)
                    
                    if voiceManager.isEnabled {
                        Picker("Voice Style", selection: $voiceManager.selectedVoiceStyle) {
                            ForEach(VoiceManager.VoiceStyle.allCases) { style in
                                Text(LocalizedStringKey(style.rawValue)).tag(style)
                            }
                        }
                        
                        Picker("Report Interval", selection: $voiceManager.interval) {
                            Text("Every 10 Jumps").tag(10)
                            Text("Every 50 Jumps").tag(50)
                            Text("Every 100 Jumps").tag(100)
                        }
                    }
                }
                
                Section(header: Text("Sensor Tuning"), footer: Text("Adjust if JumpOrange undercounts or overcounts jumps. Lower sensitivity requires harder jumps to register.")) {
                    Picker("Sensitivity", selection: Binding(
                        get: { storageManager.jumpSensitivity },
                        set: { newValue in
                            storageManager.jumpSensitivity = newValue
                            updateThreshold(for: newValue)
                        }
                    )) {
                        Text("Low (Hard Jumps)").tag(0)
                        Text("Medium (Normal)").tag(1)
                        Text("High (Light Jumps)").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                // Initialize the threshold on load
                updateThreshold(for: storageManager.jumpSensitivity)
                
                // Sync voice manager with storage manager (AppStorage)
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
        }
    }
    
    private func updateThreshold(for sensitivity: Int) {
        switch sensitivity {
        case 0: // Low sensitivity
            motionManager.jumpThreshold = 1.6
        case 1: // Medium
            motionManager.jumpThreshold = 1.2
        case 2: // High
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
