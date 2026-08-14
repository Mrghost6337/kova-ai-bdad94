import SwiftUI

struct HistoryView: View {
    @Environment(WorkoutStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KOVATokens.xxl) {
                hero
                stats
                historyList
            }
            .padding(.horizontal, KOVATokens.screenMargin)
            .padding(.top, KOVATokens.md)
            .padding(.bottom, KOVATokens.xxl)
        }
        .background(KOVATokens.background)
        .navigationTitle("History")
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

    private var hero: some View {
        KOVACard {
            VStack(alignment: .leading, spacing: KOVATokens.sm) {
                Text("Consistency")
                    .font(KOVATokens.eyebrowFont)
                    .kerning(KOVATokens.xxs)
                    .foregroundStyle(KOVATokens.secondaryText)
                Text("\(store.streak) days")
                    .font(KOVATokens.displayFont)
                    .foregroundStyle(KOVATokens.text)
                    .monospacedDigit()
                Text("Keep your current run with one focused session today.")
                    .font(KOVATokens.bodyFont)
                    .foregroundStyle(KOVATokens.secondaryText)
                WeekStrip(logs: store.workoutHistory)
                    .padding(.top, KOVATokens.sm)
            }
        }
    }

    private var stats: some View {
        HStack(spacing: KOVATokens.md) {
            KOVACard { MetricLabel(label: "This week", value: "\(store.weeklySessions) sessions") }
            KOVACard { MetricLabel(label: "Volume", value: "\(store.weeklyVolume / 1_000)k kg") }
        }
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: KOVATokens.md) {
            Text("Sessions")
                .font(KOVATokens.titleFont)
                .foregroundStyle(KOVATokens.text)
            ForEach(store.workoutHistory.sorted { $0.date > $1.date }) { log in
                KOVACard {
                    HStack(spacing: KOVATokens.md) {
                        Image(systemName: log.focus.symbol)
                            .foregroundStyle(KOVATokens.text)
                            .frame(width: KOVATokens.iconTarget, height: KOVATokens.iconTarget)
                            .background(KOVATokens.surfaceRaised, in: RoundedRectangle(cornerRadius: KOVATokens.controlRadius, style: .continuous))
                        VStack(alignment: .leading, spacing: KOVATokens.xxs) {
                            Text(log.planTitle)
                                .font(KOVATokens.headlineFont)
                                .foregroundStyle(KOVATokens.text)
                                .lineLimit(2)
                            Text(log.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                .font(KOVATokens.captionFont)
                                .foregroundStyle(KOVATokens.secondaryText)
                        }
                        Spacer(minLength: KOVATokens.xs)
                        VStack(alignment: .trailing, spacing: KOVATokens.xxs) {
                            Text("\(log.durationMinutes) min")
                                .font(KOVATokens.headlineFont)
                                .foregroundStyle(KOVATokens.text)
                            Text("RPE \(log.rpe)")
                                .font(KOVATokens.captionFont)
                                .foregroundStyle(KOVATokens.secondaryText)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .environment(WorkoutStore())
    .preferredColorScheme(.dark)
}
