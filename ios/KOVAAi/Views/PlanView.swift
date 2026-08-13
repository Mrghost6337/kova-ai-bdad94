import SwiftUI

struct PlanView: View {
    @Environment(WorkoutStore.self) private var store

    private let phases = [
        ("Foundation", "Weeks 1–2", "Build repeatable form and effort"),
        ("Progression", "Weeks 3–6", "Add load or reps when feedback allows"),
        ("Consolidation", "Week 7", "Hold quality work and assess recovery")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KOVATokens.xxl) {
                planHero
                phaseList
                nextSession
            }
            .padding(.horizontal, KOVATokens.screenMargin)
            .padding(.top, KOVATokens.md)
            .padding(.bottom, KOVATokens.xxl)
        }
        .background(KOVATokens.background)
        .navigationTitle("Plan")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: KOVATokens.xxs) {
                    Image(systemName: "flame.fill")
                    Text("\(store.streak)")
                        .monospacedDigit()
                }
                .font(KOVATokens.headlineFont)
                .foregroundStyle(KOVATokens.text)
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }

    private var planHero: some View {
        KOVACard {
            VStack(alignment: .leading, spacing: KOVATokens.md) {
                Text("Program")
                    .font(KOVATokens.eyebrowFont)
                    .kerning(KOVATokens.xxs)
                    .foregroundStyle(KOVATokens.secondaryText)
                Text("\(store.profile.goal.rawValue) block")
                    .font(KOVATokens.displayFont)
                    .foregroundStyle(KOVATokens.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                HStack(spacing: KOVATokens.xl) {
                    MetricLabel(label: "Cadence", value: "\(store.profile.daysPerWeek)d/week")
                    MetricLabel(label: "Equipment", value: store.profile.equipment)
                }
            }
        }
    }

    private var phaseList: some View {
        VStack(alignment: .leading, spacing: KOVATokens.md) {
            Text("Phases")
                .font(KOVATokens.titleFont)
                .foregroundStyle(KOVATokens.text)
            ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                KOVACard {
                    HStack(alignment: .top, spacing: KOVATokens.md) {
                        Text("\(index + 1)")
                            .font(KOVATokens.headlineFont)
                            .foregroundStyle(KOVATokens.onAccent)
                            .frame(width: KOVATokens.iconTarget, height: KOVATokens.iconTarget)
                            .background(KOVATokens.accent, in: Circle())
                        VStack(alignment: .leading, spacing: KOVATokens.xxs) {
                            Text(phase.0)
                                .font(KOVATokens.headlineFont)
                                .foregroundStyle(KOVATokens.text)
                            Text(phase.1)
                                .font(KOVATokens.captionFont)
                                .foregroundStyle(KOVATokens.secondaryText)
                            Text(phase.2)
                                .font(KOVATokens.bodyFont)
                                .foregroundStyle(KOVATokens.secondaryText)
                        }
                    }
                }
            }
        }
    }

    private var nextSession: some View {
        VStack(alignment: .leading, spacing: KOVATokens.md) {
            Text("Next")
                .font(KOVATokens.titleFont)
                .foregroundStyle(KOVATokens.text)
            KOVACard {
                VStack(alignment: .leading, spacing: KOVATokens.xs) {
                    Text(store.recommendedWorkout.title)
                        .font(KOVATokens.headlineFont)
                        .foregroundStyle(KOVATokens.text)
                    Text("\(store.recommendedWorkout.totalSets) sets · \(store.recommendedWorkout.estimatedMinutes) minutes")
                        .font(KOVATokens.bodyFont)
                        .foregroundStyle(KOVATokens.secondaryText)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PlanView()
    }
    .environment(WorkoutStore())
    .preferredColorScheme(.dark)
}
