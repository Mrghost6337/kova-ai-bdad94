import Foundation

enum TrainingGoal: String, Codable, CaseIterable, Identifiable {
    case hypertrophy = "Hypertrophy"
    case strength = "Strength"

    var id: String { rawValue }
}

enum WorkoutFocus: String, Codable, CaseIterable, Identifiable {
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
    case upper = "Upper"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .push: return "arrow.up.forward"
        case .pull: return "arrow.down.back"
        case .legs: return "figure.strengthtraining.traditional"
        case .upper: return "figure.strengthtraining.functional"
        }
    }
}

struct Exercise: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var sets: Int
    var reps: String
    var load: String
    var restSeconds: Int

    init(id: UUID = UUID(), name: String, sets: Int, reps: String, load: String, restSeconds: Int) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.load = load
        self.restSeconds = restSeconds
    }
}

struct WorkoutPlan: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var focus: WorkoutFocus
    var estimatedMinutes: Int
    var intensityNote: String
    var exercises: [Exercise]
    var rationale: String
    var scheduledDate: Date

    init(id: UUID = UUID(), title: String, focus: WorkoutFocus, estimatedMinutes: Int, intensityNote: String, exercises: [Exercise], rationale: String, scheduledDate: Date = .now) {
        self.id = id
        self.title = title
        self.focus = focus
        self.estimatedMinutes = estimatedMinutes
        self.intensityNote = intensityNote
        self.exercises = exercises
        self.rationale = rationale
        self.scheduledDate = scheduledDate
    }

    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets } }
}

struct WorkoutLog: Identifiable, Codable, Hashable {
    let id: UUID
    var planTitle: String
    var focus: WorkoutFocus
    var date: Date
    var durationMinutes: Int
    var volume: Int
    var rpe: Int
    var soreness: Int
    var completion: Double

    init(id: UUID = UUID(), planTitle: String, focus: WorkoutFocus, date: Date, durationMinutes: Int, volume: Int, rpe: Int, soreness: Int, completion: Double) {
        self.id = id
        self.planTitle = planTitle
        self.focus = focus
        self.date = date
        self.durationMinutes = durationMinutes
        self.volume = volume
        self.rpe = rpe
        self.soreness = soreness
        self.completion = completion
    }
}

struct CoachingProfile: Codable, Hashable {
    var goal: TrainingGoal
    var daysPerWeek: Int
    var equipment: String
    var reminderHour: Int
    var reminderMinute: Int

    static let seeded = CoachingProfile(goal: .hypertrophy, daysPerWeek: 4, equipment: "Full gym", reminderHour: 18, reminderMinute: 0)
}

struct CompletedSet: Identifiable, Hashable {
    let id = UUID()
    let exerciseID: UUID
    let setNumber: Int
}
