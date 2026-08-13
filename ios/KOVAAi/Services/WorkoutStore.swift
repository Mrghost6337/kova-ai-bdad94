import Foundation
import Observation

@MainActor
@Observable
final class WorkoutStore {
    private let storageKey = "kova.workout.store.v1"

    var profile: CoachingProfile
    var recommendedWorkout: WorkoutPlan
    var workoutHistory: [WorkoutLog]
    var completedSets: [CompletedSet] = []
    var selectedDateOffset = 0
    var showOnboarding = false

    init() {
        if let saved = Self.loadSavedState(forKey: storageKey) {
            profile = saved.profile
            recommendedWorkout = saved.recommendedWorkout
            workoutHistory = saved.workoutHistory
        } else {
            profile = .seeded
            recommendedWorkout = WorkoutStore.makeWorkout(focus: .push, minutes: 58, intensity: "Progression day", rationale: "Your last pull session was controlled. Push volume is ready to progress.")
            workoutHistory = WorkoutStore.seedHistory()
            persist()
        }
    }

    var streak: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(workoutHistory.map { calendar.startOfDay(for: $0.date) })
        var count = 0
        var day = calendar.startOfDay(for: .now)
        while uniqueDays.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return max(count, 1)
    }

    var weeklySessions: Int {
        let start = Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now
        return workoutHistory.filter { $0.date >= start }.count
    }

    var weeklyVolume: Int {
        let start = Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now
        return workoutHistory.filter { $0.date >= start }.reduce(0) { $0 + $1.volume }
    }

    var lastLog: WorkoutLog? { workoutHistory.sorted { $0.date > $1.date }.first }

    func setsCompleted(for exercise: Exercise) -> Int {
        completedSets.filter { $0.exerciseID == exercise.id }.count
    }

    func markSetComplete(exercise: Exercise) {
        let completed = setsCompleted(for: exercise)
        guard completed < exercise.sets else { return }
        completedSets.append(CompletedSet(exerciseID: exercise.id, setNumber: completed + 1))
        HapticService.setCompleted()
    }

    func resetActiveSession() {
        completedSets.removeAll()
    }

    func finishWorkout(rpe: Int, soreness: Int, elapsedMinutes: Int) {
        let completion = Double(completedSets.count) / Double(max(recommendedWorkout.totalSets, 1))
        let volume = recommendedWorkout.exercises.reduce(0) { partial, exercise in
            partial + (exercise.sets * 850)
        }
        let log = WorkoutLog(planTitle: recommendedWorkout.title, focus: recommendedWorkout.focus, date: .now, durationMinutes: max(elapsedMinutes, 1), volume: volume, rpe: rpe, soreness: soreness, completion: completion)
        workoutHistory.append(log)
        completedSets.removeAll()
        adaptRecommendation(after: log)
        persist()
    }

    func swapRecommendation() {
        let nextFocus: WorkoutFocus
        switch recommendedWorkout.focus {
        case .push: nextFocus = .pull
        case .pull: nextFocus = .legs
        case .legs: nextFocus = .upper
        case .upper: nextFocus = .push
        }
        recommendedWorkout = Self.makeWorkout(focus: nextFocus, minutes: recommendedWorkout.estimatedMinutes, intensity: "Fresh stimulus", rationale: "Swapped locally to keep your week balanced across movement patterns.")
        persist()
        HapticService.selection()
    }

    func regenerateRecommendation() {
        let minutes = recommendedWorkout.estimatedMinutes == 58 ? 45 : 58
        recommendedWorkout = Self.makeWorkout(focus: recommendedWorkout.focus, minutes: minutes, intensity: "Adaptive volume", rationale: "Rebuilt from your latest effort, recovery signal, and available training time.")
        persist()
        HapticService.selection()
    }

    func updateProfile(goal: TrainingGoal, days: Int, equipment: String, hour: Int, minute: Int) {
        profile = CoachingProfile(goal: goal, daysPerWeek: days, equipment: equipment, reminderHour: hour, reminderMinute: minute)
        recommendedWorkout = Self.makeWorkout(focus: .push, minutes: 52, intensity: "Personalized start", rationale: "Built from your goal, equipment, and preferred weekly cadence.")
        persist()
    }

    private func adaptRecommendation(after log: WorkoutLog) {
        let nextFocus: WorkoutFocus
        switch log.focus {
        case .push: nextFocus = .pull
        case .pull: nextFocus = .legs
        case .legs: nextFocus = .upper
        case .upper: nextFocus = .push
        }
        let needsRecovery = log.rpe >= 9 || log.soreness >= 4
        let minutes = needsRecovery ? 42 : 58
        let intensity = needsRecovery ? "Recovery-adjusted" : "Progression ready"
        let rationale = needsRecovery
            ? "Your last session landed hard. Volume is reduced today while your next muscle group stays productive."
            : "Your last session was well-managed. Load and working sets can progress for the next muscle group."
        recommendedWorkout = Self.makeWorkout(focus: nextFocus, minutes: minutes, intensity: intensity, rationale: rationale)
    }

    private func persist() {
        let state = SavedWorkoutState(profile: profile, recommendedWorkout: recommendedWorkout, workoutHistory: workoutHistory)
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func loadSavedState(forKey key: String) -> SavedWorkoutState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SavedWorkoutState.self, from: data)
    }

    private static func makeWorkout(focus: WorkoutFocus, minutes: Int, intensity: String, rationale: String) -> WorkoutPlan {
        let exercises: [Exercise]
        switch focus {
        case .push:
            exercises = [Exercise(name: "Barbell bench press", sets: 4, reps: "6–8", load: "80 kg", restSeconds: 120), Exercise(name: "Incline dumbbell press", sets: 3, reps: "8–10", load: "30 kg", restSeconds: 90), Exercise(name: "Cable lateral raise", sets: 3, reps: "12–15", load: "12.5 kg", restSeconds: 60), Exercise(name: "Rope pressdown", sets: 3, reps: "10–12", load: "32.5 kg", restSeconds: 60)]
        case .pull:
            exercises = [Exercise(name: "Weighted pull-up", sets: 4, reps: "6–8", load: "+15 kg", restSeconds: 120), Exercise(name: "Chest-supported row", sets: 3, reps: "8–10", load: "60 kg", restSeconds: 90), Exercise(name: "Lat pulldown", sets: 3, reps: "10–12", load: "64 kg", restSeconds: 75), Exercise(name: "Incline curl", sets: 3, reps: "10–12", load: "16 kg", restSeconds: 60)]
        case .legs:
            exercises = [Exercise(name: "High-bar squat", sets: 4, reps: "5–7", load: "105 kg", restSeconds: 150), Exercise(name: "Romanian deadlift", sets: 3, reps: "8–10", load: "90 kg", restSeconds: 120), Exercise(name: "Leg press", sets: 3, reps: "10–12", load: "180 kg", restSeconds: 90), Exercise(name: "Seated leg curl", sets: 3, reps: "10–12", load: "55 kg", restSeconds: 75)]
        case .upper:
            exercises = [Exercise(name: "Dumbbell bench press", sets: 3, reps: "8–10", load: "34 kg", restSeconds: 90), Exercise(name: "Neutral-grip pulldown", sets: 3, reps: "8–10", load: "68 kg", restSeconds: 90), Exercise(name: "Machine shoulder press", sets: 3, reps: "10–12", load: "50 kg", restSeconds: 75), Exercise(name: "Cable curl", sets: 2, reps: "12–15", load: "25 kg", restSeconds: 60)]
        }
        return WorkoutPlan(title: "\(focus.rawValue) performance", focus: focus, estimatedMinutes: minutes, intensityNote: intensity, exercises: exercises, rationale: rationale)
    }

    private static func seedHistory() -> [WorkoutLog] {
        let calendar = Calendar.current
        let days = [0, 1, 2, 4, 6, 9, 12]
        let focuses: [WorkoutFocus] = [.pull, .legs, .push, .upper, .legs, .pull, .push]
        return zip(days, focuses).enumerated().compactMap { index, pair in
            guard let date = calendar.date(byAdding: .day, value: -pair.0, to: .now) else { return nil }
            return WorkoutLog(planTitle: "\(pair.1.rawValue) performance", focus: pair.1, date: date, durationMinutes: 46 + index, volume: 8_400 + (index * 550), rpe: 7 + (index % 2), soreness: 2 + (index % 3), completion: 1)
        }
    }
}

private struct SavedWorkoutState: Codable {
    var profile: CoachingProfile
    var recommendedWorkout: WorkoutPlan
    var workoutHistory: [WorkoutLog]
}
