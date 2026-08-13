import SwiftUI

struct SettingsView: View {
    @Environment(WorkoutStore.self) private var store
    @Binding var showOnboarding: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var remindersOn = false
    @State private var reminderStatus = "Reminders are off"

    var body: some View {
        Form {
            Section("Coaching") {
                LabeledContent("Goal", value: store.profile.goal.rawValue)
                LabeledContent("Cadence", value: "\(store.profile.daysPerWeek) days per week")
                LabeledContent("Equipment", value: store.profile.equipment)
                Button("Rebuild coaching profile") {
                    dismiss()
                    showOnboarding = true
                }
            }
            Section("Reminders") {
                Toggle("Daily workout reminder", isOn: $remindersOn)
                    .onChange(of: remindersOn) { _, isOn in
                        guard isOn else {
                            reminderStatus = "Reminders are off"
                            return
                        }
                        Task {
                            let scheduled = await NotificationService.scheduleDailyReminder(hour: store.profile.reminderHour, minute: store.profile.reminderMinute)
                            reminderStatus = scheduled
                                ? "Daily reminder scheduled for \(reminderTime)"
                                : "Notifications are unavailable. Enable them in Settings."
                            if !scheduled { remindersOn = false }
                        }
                    }
                Text(reminderStatus)
                    .font(KOVATokens.captionFont)
                    .foregroundStyle(KOVATokens.secondaryText)
            }
            Section("About") {
                Text("KOVA uses a local, deterministic coaching demo. No AI service or cloud account is connected.")
                    .font(KOVATokens.bodyFont)
                    .foregroundStyle(KOVATokens.secondaryText)
            }
        }
        .scrollContentBackground(.hidden)
        .background(KOVATokens.background)
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .font(KOVATokens.headlineFont)
            }
        }
    }

    private var reminderTime: String {
        let date = Calendar.current.date(from: DateComponents(hour: store.profile.reminderHour, minute: store.profile.reminderMinute)) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

#Preview {
    NavigationStack {
        SettingsView(showOnboarding: .constant(false))
    }
    .environment(WorkoutStore())
    .preferredColorScheme(.dark)
}
