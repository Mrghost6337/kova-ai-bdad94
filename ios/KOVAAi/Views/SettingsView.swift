import SwiftUI

struct SettingsView: View {
    @Environment(WorkoutStore.self) private var store
    @Binding var showOnboarding: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var remindersOn = false
    @State private var reminderStatus = "Reminders are off"
    @State private var showingDeleteConfirmation = false
    @State private var showingPasswordPrompt = false
    @State private var deletionPassword = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KOVATokens.xxl) {
                accountCard
                coachingCard
                healthCard
                remindersCard
                syncCard
                dangerZone
            }
            .padding(KOVATokens.screenMargin)
            .padding(.bottom, KOVATokens.xxl)
        }
        .background(KOVATokens.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .font(KOVATokens.headlineFont)
            }
        }
        .alert("Delete account?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) { showingPasswordPrompt = true }
        } message: {
            Text("This permanently removes your account and synced coaching data.")
        }
        .alert("Confirm password", isPresented: $showingPasswordPrompt) {
            SecureField("Password", text: $deletionPassword)
            Button("Cancel", role: .cancel) { deletionPassword = "" }
            Button("Delete account", role: .destructive) {
                let password = deletionPassword
                deletionPassword = ""
                Task { await store.deleteAccount(password: password) }
            }
        } message: {
            Text("Enter your password to permanently delete this email account.")
        }
    }

    private var accountCard: some View {
        KOVACard {
            VStack(alignment: .leading, spacing: KOVATokens.md) {
                Text("Account")
                    .font(KOVATokens.titleFont)
                    .foregroundStyle(KOVATokens.text)
                HStack(spacing: KOVATokens.md) {
                    Image(systemName: store.isAuthenticated ? "person.crop.circle.fill" : "person.crop.circle")
                        .font(KOVATokens.titleFont)
                        .foregroundStyle(KOVATokens.text)
                    VStack(alignment: .leading, spacing: KOVATokens.xxs) {
                        Text(store.isAuthenticated ? "Cloud coaching active" : "Sign in required")
                            .font(KOVATokens.headlineFont)
                            .foregroundStyle(KOVATokens.text)
                        Text(store.isAuthenticated ? "Your plan and completed sessions can sync." : "Sign in to save completed sessions and exports.")
                            .font(KOVATokens.bodyFont)
                            .foregroundStyle(KOVATokens.secondaryText)
                    }
                }
                if store.isAuthenticated {
                    Button("Sign out") {
                        Task {
                            await store.signOut()
                            dismiss()
                        }
                    }
                    .font(KOVATokens.headlineFont)
                    .foregroundStyle(KOVATokens.text)
                    .frame(maxWidth: .infinity, minHeight: KOVATokens.iconTarget)
                }
            }
        }
    }

    private var coachingCard: some View {
        KOVACard {
            VStack(alignment: .leading, spacing: KOVATokens.md) {
                Text("Coaching")
                    .font(KOVATokens.titleFont)
                    .foregroundStyle(KOVATokens.text)
                settingsRow(title: "Goal", value: store.profile.goal.rawValue, symbol: "target")
                settingsRow(title: "Cadence", value: "\(store.profile.daysPerWeek) days per week", symbol: "calendar")
                settingsRow(title: "Equipment", value: store.profile.equipment, symbol: "dumbbell")
                Button("Rebuild coaching profile") {
                    dismiss()
                    showOnboarding = true
                }
                .font(KOVATokens.headlineFont)
                .foregroundStyle(KOVATokens.text)
                .frame(maxWidth: .infinity, minHeight: KOVATokens.iconTarget)
            }
        }
    }

    private var healthCard: some View {
        KOVACard {
            VStack(alignment: .leading, spacing: KOVATokens.md) {
                Text("Apple Health")
                    .font(KOVATokens.titleFont)
                    .foregroundStyle(KOVATokens.text)
                HStack(alignment: .top, spacing: KOVATokens.md) {
                    Image(systemName: "heart.text.square")
                        .foregroundStyle(KOVATokens.text)
                        .frame(width: KOVATokens.iconTarget, height: KOVATokens.iconTarget)
                        .background(KOVATokens.surfaceRaised, in: RoundedRectangle(cornerRadius: KOVATokens.controlRadius, style: .continuous))
                    VStack(alignment: .leading, spacing: KOVATokens.xxs) {
                        Text(store.healthConnection.title)
                            .font(KOVATokens.headlineFont)
                            .foregroundStyle(KOVATokens.text)
                        Text(store.healthConnection.detail)
                            .font(KOVATokens.bodyFont)
                            .foregroundStyle(KOVATokens.secondaryText)
                    }
                }
                Button(store.healthConnection == .connected ? "Refresh permission" : "Connect Apple Health") {
                    Task { await store.connectAppleHealth() }
                }
                .buttonStyle(KOVAPrimaryButtonStyle())
                Text("Apple Health keeps read permissions private. Check Health access on your iPhone if workout context is unavailable.")
                    .font(KOVATokens.captionFont)
                    .foregroundStyle(KOVATokens.secondaryText)
            }
        }
    }

    private var remindersCard: some View {
        KOVACard {
            VStack(alignment: .leading, spacing: KOVATokens.md) {
                Text("Reminders")
                    .font(KOVATokens.titleFont)
                    .foregroundStyle(KOVATokens.text)
                Toggle("Daily workout reminder", isOn: $remindersOn)
                    .font(KOVATokens.bodyFont)
                    .tint(KOVATokens.accent)
                    .onChange(of: remindersOn) { _, isOn in
                        guard isOn else {
                            reminderStatus = "Reminders are off"
                            return
                        }
                        Task {
                            let scheduled = await NotificationService.scheduleDailyReminder(hour: store.profile.reminderHour, minute: store.profile.reminderMinute)
                            reminderStatus = scheduled ? "Daily reminder scheduled for \(reminderTime)" : "Notifications are unavailable. Enable them in Settings."
                            if !scheduled { remindersOn = false }
                        }
                    }
                Text(reminderStatus)
                    .font(KOVATokens.captionFont)
                    .foregroundStyle(KOVATokens.secondaryText)
            }
        }
    }

    private var syncCard: some View {
        KOVACard {
            VStack(alignment: .leading, spacing: KOVATokens.md) {
                Text("Data")
                    .font(KOVATokens.titleFont)
                    .foregroundStyle(KOVATokens.text)
                Button("Refresh training data") {
                    Task { await store.refreshRemoteState() }
                }
                .font(KOVATokens.headlineFont)
                .foregroundStyle(KOVATokens.text)
                .frame(maxWidth: .infinity, minHeight: KOVATokens.iconTarget)
                Button("Export training summary") {
                    Task { await store.exportTrainingSummary() }
                }
                .font(KOVATokens.headlineFont)
                .foregroundStyle(KOVATokens.text)
                .frame(maxWidth: .infinity, minHeight: KOVATokens.iconTarget)
                if store.isSyncing {
                    Text("Syncing training data…")
                        .font(KOVATokens.captionFont)
                        .foregroundStyle(KOVATokens.secondaryText)
                }
                if let exportStatus = store.exportStatus {
                    Text(exportStatus)
                        .font(KOVATokens.captionFont)
                        .foregroundStyle(KOVATokens.secondaryText)
                }
                if let backendError = store.backendError {
                    Text(backendError)
                        .font(KOVATokens.captionFont)
                        .foregroundStyle(KOVATokens.secondaryText)
                }
            }
        }
    }

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: KOVATokens.md) {
            Text("Account data")
                .font(KOVATokens.titleFont)
                .foregroundStyle(KOVATokens.text)
            Button("Delete account", role: .destructive) {
                showingDeleteConfirmation = true
            }
            .font(KOVATokens.headlineFont)
            .frame(maxWidth: .infinity, minHeight: KOVATokens.iconTarget)
        }
    }

    private func settingsRow(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: KOVATokens.sm) {
            Image(systemName: symbol)
                .foregroundStyle(KOVATokens.secondaryText)
                .frame(width: KOVATokens.iconTarget, height: KOVATokens.iconTarget)
            Text(title)
                .font(KOVATokens.bodyFont)
                .foregroundStyle(KOVATokens.text)
            Spacer()
            Text(value)
                .font(KOVATokens.captionFont)
                .foregroundStyle(KOVATokens.secondaryText)
                .multilineTextAlignment(.trailing)
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
