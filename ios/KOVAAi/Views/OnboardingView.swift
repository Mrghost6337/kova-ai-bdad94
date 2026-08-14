import SwiftUI

struct OnboardingView: View {
    @Environment(WorkoutStore.self) private var store
    let onComplete: () -> Void
    @State private var step = 0
    @State private var showingAccountSetup = false
    @State private var goal: TrainingGoal = .hypertrophy
    @State private var daysPerWeek = 4
    @State private var equipment = "Full gym"
    @State private var reminderHour = 18

    var body: some View {
        VStack(alignment: .leading, spacing: KOVATokens.xxl) {
            progress
            Spacer(minLength: KOVATokens.lg)
            stepContent
            Spacer(minLength: KOVATokens.lg)
            Button(step == 3 ? "Continue to account" : "Continue") {
                advance()
            }
            .buttonStyle(KOVAPrimaryButtonStyle())
        }
        .padding(KOVATokens.screenMargin)
        .background(KOVATokens.background)
        .fullScreenCover(isPresented: $showingAccountSetup) {
            AuthenticationView {
                HapticService.setCompleted()
                onComplete()
            }
            .environment(store)
            .preferredColorScheme(.dark)
        }
    }

    private var progress: some View {
        HStack(spacing: KOVATokens.xs) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? KOVATokens.accent : KOVATokens.progressTrack)
                    .frame(maxWidth: .infinity)
                    .frame(height: KOVATokens.xxs)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            choiceScreen(title: "Build a plan that adapts", subtitle: "KOVA uses effort and soreness feedback to tune your next workout.") {
                choiceRow("Hypertrophy", selected: goal == .hypertrophy) { goal = .hypertrophy }
                choiceRow("Strength", selected: goal == .strength) { goal = .strength }
            }
        case 1:
            choiceScreen(title: "Your weekly rhythm", subtitle: "Choose a cadence you can keep consistently.") {
                ForEach(3...5, id: \.self) { days in
                    choiceRow("\(days) days per week", selected: daysPerWeek == days) { daysPerWeek = days }
                }
            }
        case 2:
            choiceScreen(title: "Your equipment", subtitle: "We will only recommend movements you can actually do.") {
                choiceRow("Full gym", selected: equipment == "Full gym") { equipment = "Full gym" }
                choiceRow("Dumbbells + bench", selected: equipment == "Dumbbells + bench") { equipment = "Dumbbells + bench" }
                choiceRow("Minimal equipment", selected: equipment == "Minimal equipment") { equipment = "Minimal equipment" }
            }
        default:
            choiceScreen(title: "Your plan is ready", subtitle: "Set your reminder now. Your account will keep this plan and every completed session in sync.") {
                Picker("Reminder time", selection: $reminderHour) {
                    ForEach(6...21, id: \.self) { hour in
                        Text(hourLabel(hour)).tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .tint(KOVATokens.text)
            }
        }
    }

    private func choiceScreen<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: KOVATokens.xl) {
            Text(title)
                .font(KOVATokens.displayFont)
                .foregroundStyle(KOVATokens.text)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
            Text(subtitle)
                .font(KOVATokens.bodyFont)
                .foregroundStyle(KOVATokens.secondaryText)
            VStack(spacing: KOVATokens.sm) {
                content()
            }
        }
    }

    private func choiceRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticService.selection()
        } label: {
            HStack {
                Text(title)
                    .font(KOVATokens.headlineFont)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            }
            .foregroundStyle(selected ? KOVATokens.onAccent : KOVATokens.text)
            .padding(.horizontal, KOVATokens.md)
            .frame(minHeight: KOVATokens.buttonHeight)
            .background(selected ? KOVATokens.accent : KOVATokens.surfaceRaised, in: RoundedRectangle(cornerRadius: KOVATokens.cardRadius, style: .continuous))
        }
    }

    private func advance() {
        if step < 3 {
            step += 1
            HapticService.selection()
        } else {
            store.updateProfile(goal: goal, days: daysPerWeek, equipment: equipment, hour: reminderHour, minute: 0)
            Task { _ = await NotificationService.scheduleDailyReminder(hour: reminderHour, minute: 0) }
            showingAccountSetup = true
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .environment(WorkoutStore())
        .preferredColorScheme(.dark)
}
