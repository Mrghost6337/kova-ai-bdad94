import SwiftUI

struct SessionView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var restSecondsRemaining = 0
    @State private var activeRestExercise: Exercise?
    @State private var elapsedSeconds = 0
    @State private var showFeedback = false
    @State private var isSessionComplete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KOVATokens.xxl) {
                    sessionHeader
                    exerciseList
                }
                .padding(.horizontal, KOVATokens.screenMargin)
                .padding(.top, KOVATokens.md)
                .padding(.bottom, KOVATokens.xxl)
            }
            .background(KOVATokens.background)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("End") { dismiss() }
                        .font(KOVATokens.headlineFont)
                        .foregroundStyle(KOVATokens.text)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text(formattedElapsed)
                        .font(KOVATokens.headlineFont)
                        .foregroundStyle(KOVATokens.text)
                        .monospacedDigit()
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if restSecondsRemaining > 0 {
                    restTimerBar
                } else if isSessionComplete {
                    Button("Finish & adapt next workout") {
                        showFeedback = true
                    }
                    .buttonStyle(KOVAPrimaryButtonStyle())
                    .padding(.horizontal, KOVATokens.screenMargin)
                    .padding(.vertical, KOVATokens.sm)
                    .background(KOVATokens.background)
                }
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                elapsedSeconds += 1
            }
        }
        .task(id: restSecondsRemaining) {
            guard restSecondsRemaining > 0 else { return }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard restSecondsRemaining > 0 else { return }
            restSecondsRemaining -= 1
            if restSecondsRemaining == 0 {
                activeRestExercise = nil
                HapticService.restFinished()
            }
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView(elapsedMinutes: max(elapsedSeconds / 60, 1)) {
                dismiss()
            }
            .environment(store)
            .preferredColorScheme(.dark)
            .presentationDetents([.large])
        }
        .onAppear { store.resetActiveSession() }
    }

    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: KOVATokens.xs) {
            Text(store.recommendedWorkout.focus.rawValue.uppercased())
                .font(KOVATokens.eyebrowFont)
                .kerning(KOVATokens.xxs)
                .foregroundStyle(KOVATokens.secondaryText)
            Text(store.recommendedWorkout.title)
                .font(KOVATokens.titleFont)
                .foregroundStyle(KOVATokens.text)
            Text("Complete a set to start its rest timer. KOVA will vibrate when recovery is done.")
                .font(KOVATokens.bodyFont)
                .foregroundStyle(KOVATokens.secondaryText)
        }
    }

    private var exerciseList: some View {
        VStack(spacing: KOVATokens.md) {
            ForEach(store.recommendedWorkout.exercises) { exercise in
                sessionExerciseCard(exercise)
            }
        }
    }

    private func sessionExerciseCard(_ exercise: Exercise) -> some View {
        let completed = store.setsCompleted(for: exercise)
        return KOVACard {
            VStack(alignment: .leading, spacing: KOVATokens.md) {
                HStack(alignment: .top, spacing: KOVATokens.md) {
                    VStack(alignment: .leading, spacing: KOVATokens.xxs) {
                        Text(exercise.name)
                            .font(KOVATokens.headlineFont)
                            .foregroundStyle(KOVATokens.text)
                            .lineLimit(2)
                        Text("\(exercise.reps) reps · \(exercise.load) · \(exercise.restSeconds)s rest")
                            .font(KOVATokens.captionFont)
                            .foregroundStyle(KOVATokens.secondaryText)
                    }
                    Spacer(minLength: KOVATokens.xs)
                    Text("\(completed)/\(exercise.sets)")
                        .font(KOVATokens.headlineFont)
                        .foregroundStyle(KOVATokens.text)
                        .monospacedDigit()
                }
                HStack(spacing: KOVATokens.xs) {
                    ForEach(1...exercise.sets, id: \.self) { set in
                        let done = set <= completed
                        Text("\(set)")
                            .font(KOVATokens.captionFont)
                            .foregroundStyle(done ? KOVATokens.onAccent : KOVATokens.secondaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: KOVATokens.iconTarget)
                            .background(done ? KOVATokens.accent : KOVATokens.surfaceRaised, in: RoundedRectangle(cornerRadius: KOVATokens.controlRadius, style: .continuous))
                    }
                }
                Button {
                    store.markSetComplete(exercise: exercise)
                    activeRestExercise = exercise
                    restSecondsRemaining = exercise.restSeconds
                    isSessionComplete = store.completedSets.count == store.recommendedWorkout.totalSets
                } label: {
                    Label(completed == exercise.sets ? "All sets complete" : "Log next set", systemImage: completed == exercise.sets ? "checkmark" : "plus")
                        .font(KOVATokens.headlineFont)
                        .foregroundStyle(completed == exercise.sets ? KOVATokens.secondaryText : KOVATokens.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: KOVATokens.iconTarget)
                        .background(KOVATokens.surfaceRaised, in: Capsule())
                }
                .disabled(completed == exercise.sets)
            }
        }
    }

    private var restTimerBar: some View {
        HStack(spacing: KOVATokens.md) {
            Image(systemName: "timer")
                .foregroundStyle(KOVATokens.text)
            VStack(alignment: .leading, spacing: KOVATokens.xxs) {
                Text("Resting after \(activeRestExercise?.name ?? "set")")
                    .font(KOVATokens.captionFont)
                    .foregroundStyle(KOVATokens.secondaryText)
                    .lineLimit(2)
                Text(formattedRest)
                    .font(KOVATokens.titleFont)
                    .foregroundStyle(KOVATokens.text)
                    .monospacedDigit()
            }
            Spacer()
            Button("Skip") {
                restSecondsRemaining = 0
                activeRestExercise = nil
                HapticService.selection()
            }
            .font(KOVATokens.headlineFont)
            .foregroundStyle(KOVATokens.text)
        }
        .padding(.horizontal, KOVATokens.screenMargin)
        .padding(.vertical, KOVATokens.sm)
        .background(KOVATokens.surfaceRaised)
        .overlay(alignment: .top) { Rectangle().fill(KOVATokens.border).frame(height: 1) }
    }

    private var formattedElapsed: String {
        String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    private var formattedRest: String {
        String(format: "%02d:%02d", restSecondsRemaining / 60, restSecondsRemaining % 60)
    }
}

struct FeedbackView: View {
    @Environment(WorkoutStore.self) private var store
    let elapsedMinutes: Int
    let onComplete: () -> Void
    @State private var rpe = 8
    @State private var soreness = 2

    var body: some View {
        VStack(alignment: .leading, spacing: KOVATokens.xxl) {
            VStack(alignment: .leading, spacing: KOVATokens.xs) {
                Text("Session review")
                    .font(KOVATokens.titleFont)
                    .foregroundStyle(KOVATokens.text)
                Text("Your answers tune the next session locally.")
                    .font(KOVATokens.bodyFont)
                    .foregroundStyle(KOVATokens.secondaryText)
            }
            feedbackPicker(title: "How hard was it?", value: $rpe, range: 6...10, suffix: "/10")
            feedbackPicker(title: "Current soreness", value: $soreness, range: 1...5, suffix: "/5")
            Spacer(minLength: KOVATokens.md)
            Button("Save feedback") {
                store.finishWorkout(rpe: rpe, soreness: soreness, elapsedMinutes: elapsedMinutes)
                HapticService.setCompleted()
                onComplete()
            }
            .buttonStyle(KOVAPrimaryButtonStyle())
        }
        .padding(KOVATokens.screenMargin)
        .background(KOVATokens.background)
    }

    private func feedbackPicker(title: String, value: Binding<Int>, range: ClosedRange<Int>, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: KOVATokens.md) {
            Text(title)
                .font(KOVATokens.headlineFont)
                .foregroundStyle(KOVATokens.text)
            HStack(spacing: KOVATokens.xs) {
                ForEach(Array(range), id: \.self) { score in
                    Button {
                        value.wrappedValue = score
                        HapticService.selection()
                    } label: {
                        Text("\(score)\(suffix)")
                            .font(KOVATokens.captionFont)
                            .foregroundStyle(value.wrappedValue == score ? KOVATokens.onAccent : KOVATokens.text)
                            .frame(maxWidth: .infinity)
                            .frame(height: KOVATokens.iconTarget)
                            .background(value.wrappedValue == score ? KOVATokens.accent : KOVATokens.surfaceRaised, in: RoundedRectangle(cornerRadius: KOVATokens.controlRadius, style: .continuous))
                    }
                }
            }
        }
    }
}

#Preview {
    SessionView()
        .environment(WorkoutStore())
        .preferredColorScheme(.dark)
}
