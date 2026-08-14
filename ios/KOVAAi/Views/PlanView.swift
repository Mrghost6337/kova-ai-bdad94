import SwiftUI

struct PlanView: View {
    @Environment(WorkoutStore.self) private var store

    private let phases = [
        ("Foundation", "Weeks 1–2", "Build repeatable form and effort"),
        ("Progression", "Weeks 3–6", "Add load or reps when feedback allows"),
        ("Consolidation", "Week 7", "Hold quality work and assess recovery")
    ]

    private var activePhaseIndex: Int {
        store.weeklySessions >= store.profile.daysPerWeek ? 1 : 0
    }

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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.streak > 0 {
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
    }

    private var planHero: some View {
        KOVACard {
            VStack(alignment: .leading, spacing: KOVATokens.lg) {
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
                    MetricLabel(label: "Completed", value: "\(store.weeklySessions)")
                    MetricLabel(label: "Volume", value: "\(store.weeklyVolume.formatted()) kg")
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
                        Image(systemName: index < activePhaseIndex ? "checkmark" : "\(index + 1).circle")
                            .font(KOVATokens.headlineFont)
                            .foregroundStyle(index == activePhaseIndex ? KOVATokens.onAccent : KOVATokens.text)
                            .frame(width: KOVATokens.iconTarget, height: KOVATokens.iconTarget)
                            .background(index == activePhaseIndex ? KOVATokens.accent : KOVATokens.surfaceRaised, in: Circle())
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
                VStack(alignment: .leading, spacing: KOVATokens.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: KOVATokens.xxs) {
                            Text(store.recommendedWorkout.title)
                                .font(KOVATokens.headlineFont)
                                .foregroundStyle(KOVATokens.text)
                            Text("\(store.recommendedWorkout.totalSets) sets · \(store.recommendedWorkout.estimatedMinutes) minutes")
                                .font(KOVATokens.bodyFont)
                                .foregroundStyle(KOVATokens.secondaryText)
                        }
                        Spacer()
                        Image(systemName: store.recommendedWorkout.focus.symbol)
                            .foregroundStyle(KOVATokens.text)
                            .frame(width: KOVATokens.iconTarget, height: KOVATokens.iconTarget)
                            .background(KOVATokens.surfaceRaised, in: RoundedRectangle(cornerRadius: KOVATokens.controlRadius, style: .continuous))
                    }
                    ForEach(store.recommendedWorkout.exercises.prefix(3)) { exercise in
                        WorkoutPreviewRow(exercise: exercise, completedSets: 0)
                    }
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
