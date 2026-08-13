import SwiftUI

struct KOVACard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(KOVATokens.md)
            .background(KOVATokens.surface, in: RoundedRectangle(cornerRadius: KOVATokens.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: KOVATokens.cardRadius, style: .continuous)
                    .stroke(KOVATokens.border, lineWidth: 1)
            }
    }
}

struct MetricLabel: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: KOVATokens.xxs) {
            Text(label.uppercased())
                .font(KOVATokens.eyebrowFont)
                .kerning(KOVATokens.xxs)
                .foregroundStyle(KOVATokens.secondaryText)
            Text(value)
                .font(KOVATokens.headlineFont)
                .foregroundStyle(KOVATokens.text)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WeekStrip: View {
    let logs: [WorkoutLog]

    private var days: [Date] {
        let calendar = Calendar.current
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0 - 6, to: .now) }
    }

    var body: some View {
        HStack(spacing: KOVATokens.xs) {
            ForEach(days, id: \.self) { day in
                let completed = logs.contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
                let today = Calendar.current.isDateInToday(day)
                VStack(spacing: KOVATokens.xs) {
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(KOVATokens.captionFont)
                        .foregroundStyle(KOVATokens.secondaryText)
                    Circle()
                        .fill(completed ? KOVATokens.accent : KOVATokens.surfaceRaised)
                        .frame(width: KOVATokens.sm, height: KOVATokens.sm)
                        .overlay {
                            if today {
                                Circle().stroke(KOVATokens.text, lineWidth: 1)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct WorkoutPreviewRow: View {
    let exercise: Exercise
    let completedSets: Int

    var body: some View {
        HStack(spacing: KOVATokens.sm) {
            Image(systemName: completedSets == exercise.sets ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(completedSets == exercise.sets ? KOVATokens.text : KOVATokens.tertiaryText)
                .frame(width: KOVATokens.iconTarget, height: KOVATokens.iconTarget)
            VStack(alignment: .leading, spacing: KOVATokens.xxs) {
                Text(exercise.name)
                    .font(KOVATokens.headlineFont)
                    .foregroundStyle(KOVATokens.text)
                    .lineLimit(2)
                Text("\(exercise.sets) sets · \(exercise.reps) · \(exercise.load)")
                    .font(KOVATokens.captionFont)
                    .foregroundStyle(KOVATokens.secondaryText)
            }
            Spacer(minLength: KOVATokens.xs)
            Text("\(completedSets)/\(exercise.sets)")
                .font(KOVATokens.captionFont)
                .foregroundStyle(KOVATokens.secondaryText)
                .monospacedDigit()
        }
    }
}

struct MiniProgressRing: View {
    let progress: Double
    let value: String
    let label: String

    var body: some View {
        ZStack {
            Circle().stroke(KOVATokens.progressTrack, lineWidth: KOVATokens.ringLineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(KOVATokens.accent, style: StrokeStyle(lineWidth: KOVATokens.ringLineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: KOVATokens.xxs) {
                Text(value)
                    .font(KOVATokens.headlineFont)
                    .foregroundStyle(KOVATokens.text)
                    .monospacedDigit()
                Text(label)
                    .font(KOVATokens.captionFont)
                    .foregroundStyle(KOVATokens.secondaryText)
            }
        }
        .frame(width: KOVATokens.huge * 2, height: KOVATokens.huge * 2)
        .animation(.smooth, value: progress)
    }
}
