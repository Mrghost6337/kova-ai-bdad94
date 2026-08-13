import SwiftUI

struct TodayView: View {
    @Environment(WorkoutStore.self) private var store
    @Binding var showSettings: Bool
    @State private var showSession = false
    @State private var showSwapMenu = false

    private var displayedDate: Date {
        Calendar.current.date(byAdding: .day, value: store.selectedDateOffset, to: .now) ?? .now
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KOVATokens.xxl) {
                daySwitcher
                workoutHero
                guidanceCard
                trainingWeek
            }
            .padding(.horizontal, KOVATokens.screenMargin)
            .padding(.top, KOVATokens.md)
            .padding(.bottom, KOVATokens.xxl)
        }
        .background(KOVATokens.background)
        .navigationTitle("")
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
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .frame(width: KOVATokens.iconTarget, height: KOVATokens.iconTarget)
                }
                .accessibilityLabel("Settings")
            }
        }
        .fullScreenCover(isPresented: $showSession) {
            SessionView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
        .confirmationDialog("Adjust today", isPresented: $showSwapMenu, titleVisibility: .visible) {
            Button("Swap focus") { store.swapRecommendation() }
            Button("Regenerate volume") { store.regenerateRecommendation() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var daySwitcher: some View {
        HStack(spacing: KOVATokens.sm) {
            Button {
                store.selectedDateOffset -= 1
                HapticService.selection()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: KOVATokens.iconTarget, height: KOVATokens.iconTarget)
            }
            VStack(alignment: .leading, spacing: KOVATokens.xxs) {
                Text(store.selectedDateOffset == 0 ? "Today" : displayedDate.formatted(.dateTime.weekday(.wide)))
                    .font(KOVATokens.titleFont)
                    .foregroundStyle(KOVATokens.text)
                Text(displayedDate.formatted(.dateTime.month(.wide).day()))
                    .font(KOVATokens.captionFont)
                    .foregroundStyle(KOVATokens.secondaryText)
            }
            Spacer()
            Button {
                store.selectedDateOffset = 0
                HapticService.selection()
            } label: {
                Text("Today")
                    .font(KOVATokens.captionFont)
                    .foregroundStyle(KOVATokens.text)
                    .padding(.horizontal, KOVATokens.sm)
                    .frame(height: KOVATokens.iconTarget)
                    .background(KOVATokens.surfaceRaised, in: Capsule())
            }
            Button {
                store.selectedDateOffset += 1
                HapticService.selection()
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: KOVATokens.iconTarget, height: KOVATokens.iconTarget)
            }
        }
    }

    private var workoutHero: some View {
        KOVACard {
            VStack(alignment: .leading, spacing: KOVATokens.xl) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: KOVATokens.xs) {
                        Text(store.recommendedWorkout.intensityNote.uppercased())
                            .font(KOVATokens.eyebrowFont)
                            .kerning(KOVATokens.xxs)
                            .foregroundStyle(KOVATokens.secondaryText)
                        Text(store.recommendedWorkout.title)
                            .font(KOVATokens.displayFont)
                            .foregroundStyle(KOVATokens.text)
                            .lineLimit(2)
                            .minimumScaleFactor(0.76)
                    }
                    Spacer(minLength: KOVATokens.md)
                    Image(systemName: store.recommendedWorkout.focus.symbol)
                        .font(KOVATokens.titleFont)
                        .foregroundStyle(KOVATokens.text)
                        .frame(width: KOVATokens.huge, height: KOVATokens.huge)
                        .background(KOVATokens.surfaceRaised, in: RoundedRectangle(cornerRadius: KOVATokens.controlRadius, style: .continuous))
                }
                HStack(spacing: KOVATokens.xl) {
                    MetricLabel(label: "Time", value: "\(store.recommendedWorkout.estimatedMinutes) min")
                    MetricLabel(label: "Sets", value: "\(store.recommendedWorkout.totalSets)")
                    MetricLabel(label: "Focus", value: store.recommendedWorkout.focus.rawValue)
                }
                Button {
                    showSession = true
                    HapticService.selection()
                } label: {
                    Label("Start session", systemImage: "play.fill")
                }
                .buttonStyle(KOVAPrimaryButtonStyle())
                Button {
                    showSwapMenu = true
                } label: {
                    Label("Swap or regenerate", systemImage: "arrow.triangle.2.circlepath")
                        .font(KOVATokens.headlineFont)
                        .foregroundStyle(KOVATokens.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: KOVATokens.iconTarget)
                }
            }
        }
    }

    private var guidanceCard: some View {
        KOVACard {
            HStack(alignment: .top, spacing: KOVATokens.md) {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(KOVATokens.text)
                    .frame(width: KOVATokens.iconTarget, height: KOVATokens.iconTarget)
                    .background(KOVATokens.surfaceRaised, in: RoundedRectangle(cornerRadius: KOVATokens.controlRadius, style: .continuous))
                VStack(alignment: .leading, spacing: KOVATokens.xs) {
                    Text("Why this session")
                        .font(KOVATokens.headlineFont)
                        .foregroundStyle(KOVATokens.text)
                    Text(store.recommendedWorkout.rationale)
                        .font(KOVATokens.bodyFont)
                        .foregroundStyle(KOVATokens.secondaryText)
                }
            }
        }
    }

    private var trainingWeek: some View {
        VStack(alignment: .leading, spacing: KOVATokens.md) {
            HStack {
                Text("This week")
                    .font(KOVATokens.titleFont)
                    .foregroundStyle(KOVATokens.text)
                Spacer()
                Text("\(store.weeklySessions)/\(store.profile.daysPerWeek) sessions")
                    .font(KOVATokens.captionFont)
                    .foregroundStyle(KOVATokens.secondaryText)
            }
            KOVACard {
                WeekStrip(logs: store.workoutHistory)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TodayView(showSettings: .constant(false))
    }
    .environment(WorkoutStore())
    .preferredColorScheme(.dark)
}
