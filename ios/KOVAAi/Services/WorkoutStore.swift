import Foundation
import Observation

@MainActor
@Observable
final class WorkoutStore {
    private let storageKey = "kova.workout.store.v1"
    private let backendClient = BackendClient()
    private let dataClient = TenxData()
    private let storageClient = TenxStorage()

    var profile: CoachingProfile
    var recommendedWorkout: WorkoutPlan
    var workoutHistory: [WorkoutLog]
    var completedSets: [CompletedSet] = []
    var selectedDateOffset = 0
    var showOnboarding = false
    var isAuthenticated = false
    var isSyncing = false
    var backendError: String?
    var exportStatus: String?
    var healthConnection: HealthConnectionState = .notConnected

    init() {
        if let saved = Self.loadSavedState(forKey: storageKey) {
            profile = saved.profile
            recommendedWorkout = saved.recommendedWorkout
            workoutHistory = saved.workoutHistory.isEmpty ? Self.seededHistory : saved.workoutHistory
            persist()
        } else {
            profile = .seeded
            recommendedWorkout = Self.makeWorkout(focus: .push, minutes: 58, intensity: "Progression day", rationale: "Your first progression session is ready.")
            workoutHistory = Self.seededHistory
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
        return count
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

    func restoreSession() async {
        isAuthenticated = await TenxSession.shared.isSignedIn
        guard isAuthenticated else { return }
        await refreshRemoteState()
    }

    func signIn(email: String, password: String, createAccount: Bool) async throws {
        if createAccount {
            _ = try await TenxSession.shared.signUp(email: email, password: password)
        } else {
            _ = try await TenxSession.shared.signIn(email: email, password: password)
        }
        isAuthenticated = true
        await refreshRemoteState()
    }

    func signOut() async {
        await TenxSession.shared.signOut()
        isAuthenticated = false
        backendError = nil
    }

    func connectAppleHealth() async {
        healthConnection = .requesting
        healthConnection = await HealthKitService.requestWorkoutReadAccess()
    }

    func deleteAccount(password: String?) async {
        do {
            try await TenxSession.shared.deleteAccount(password: password)
            isAuthenticated = false
            backendError = nil
            exportStatus = "Account deleted."
        } catch {
            backendError = error.localizedDescription
        }
    }

    func refreshRemoteState() async {
        guard isAuthenticated else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let token = try await TenxSession.shared.validAccessToken()
            async let plan: RemotePlan = backendClient.get(RemotePlan.self, path: "/api/v1/active-plan", accessToken: token)
            async let history: RemoteHistory = backendClient.get(RemoteHistory.self, path: "/api/v1/workout-history", accessToken: token)
            let profileData = try await dataClient.select(table: "coaching_profiles", accessToken: token)
            recommendedWorkout = try await plan.asWorkoutPlan()
            workoutHistory = try await history.items.map { try $0.asWorkoutLog() }
            if let remoteProfile = try JSONDecoder.tenxDecoder.decode([RemoteProfile].self, from: profileData).first {
                profile = remoteProfile.asProfile(using: profile)
            }
            persist()
            backendError = nil
        } catch {
            backendError = error.localizedDescription
        }
    }

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

    func finishWorkout(rpe: Int, soreness: Int, elapsedMinutes: Int) async {
        let completion = Double(completedSets.count) / Double(max(recommendedWorkout.totalSets, 1))
        let volume = recommendedWorkout.exercises.reduce(0) { $0 + ($1.sets * 850) }
        let log = WorkoutLog(planTitle: recommendedWorkout.title, focus: recommendedWorkout.focus, date: .now, durationMinutes: max(elapsedMinutes, 1), volume: volume, rpe: rpe, soreness: soreness, completion: completion)
        guard isAuthenticated else {
            backendError = "Sign in to save a completed workout."
            return
        }
        do {
            let token = try await TenxSession.shared.validAccessToken()
            let payload = CompletionPayload(planID: recommendedWorkout.id, durationMinutes: log.durationMinutes, volumeKg: log.volume, rpe: rpe, soreness: soreness, completedSets: completedSets.count)
            let response: CompletionResponse = try await backendClient.send(CompletionResponse.self, path: "/api/v1/workout-completions", body: payload, accessToken: token, encoder: .tenxEncoder)
            workoutHistory.append(log)
            recommendedWorkout = try response.nextPlan.asWorkoutPlan()
            completedSets.removeAll()
            persist()
            backendError = nil
        } catch {
            backendError = error.localizedDescription
        }
    }

    func swapRecommendation() {
        let focusOrder = WorkoutFocus.allCases
        guard let currentIndex = focusOrder.firstIndex(of: recommendedWorkout.focus) else { return }
        let nextFocus = focusOrder[(currentIndex + 1) % focusOrder.count]
        recommendedWorkout = Self.makeWorkout(
            focus: nextFocus,
            minutes: recommendedWorkout.estimatedMinutes,
            intensity: recommendedWorkout.intensityNote,
            rationale: "A fresh \(nextFocus.rawValue.lowercased()) session keeps today aligned with your training block."
        )
        persist()
        HapticService.selection()
    }

    func regenerateRecommendation() {
        let adjustedMinutes = max(recommendedWorkout.estimatedMinutes - 8, 40)
        recommendedWorkout = Self.makeWorkout(
            focus: recommendedWorkout.focus,
            minutes: adjustedMinutes,
            intensity: "Refined volume",
            rationale: "Volume has been tightened for a focused \(adjustedMinutes)-minute session."
        )
        persist()
        HapticService.selection()
    }

    func updateProfile(goal: TrainingGoal, days: Int, equipment: String, hour: Int, minute: Int) {
        profile = CoachingProfile(goal: goal, daysPerWeek: days, equipment: equipment, reminderHour: hour, reminderMinute: minute)
        persist()
        Task { await syncProfile() }
    }

    func exportTrainingSummary() async {
        guard isAuthenticated else {
            exportStatus = "Sign in to export your training summary."
            return
        }
        guard TenxProject.storageBuckets.contains("workout-exports") else {
            exportStatus = "Workout exports are not configured yet."
            return
        }
        do {
            let token = try await TenxSession.shared.validAccessToken()
            let data = try JSONEncoder.tenxEncoder.encode(ExportSummary(profile: profile, workouts: workoutHistory))
            let filename = "kova-training-summary-\(Date.now.formatted(date: .numeric, time: .omitted)).json".replacingOccurrences(of: "/", with: "-")
            let object = try await storageClient.upload(data: data, bucket: "workout-exports", filename: filename, contentType: "application/json", accessToken: token)
            let objects = try await storageClient.listObjects(bucket: "workout-exports", accessToken: token)
            exportStatus = objects.contains(where: { $0.id == object.id }) ? "Training summary exported." : "Export needs confirmation."
        } catch {
            exportStatus = error.localizedDescription
        }
    }

    private func syncProfile() async {
        guard isAuthenticated else { return }
        do {
            let token = try await TenxSession.shared.validAccessToken()
            let payload = RemoteProfileUpdate(goal: profile.goal.rawValue.lowercased(), daysPerWeek: profile.daysPerWeek, equipment: profile.equipment)
            let _: RemoteProfile = try await backendClient.send(RemoteProfile.self, path: "/api/v1/profile", method: "PUT", body: payload, accessToken: token, encoder: .tenxEncoder)
            let profileData = try await dataClient.select(table: "coaching_profiles", accessToken: token)
            if let confirmed = try JSONDecoder.tenxDecoder.decode([RemoteProfile].self, from: profileData).first {
                profile = confirmed.asProfile(using: profile)
                persist()
            }
        } catch {
            backendError = error.localizedDescription
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(SavedWorkoutState(profile: profile, recommendedWorkout: recommendedWorkout, workoutHistory: workoutHistory)) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func loadSavedState(forKey key: String) -> SavedWorkoutState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SavedWorkoutState.self, from: data)
    }

    private static var seededHistory: [WorkoutLog] {
        let calendar = Calendar.current
        let sessions: [(Int, WorkoutFocus, String, Int, Int, Int, Int)] = [
            (0, .pull, "Pull performance", 62, 15_480, 8, 3),
            (1, .legs, "Legs performance", 68, 18_920, 8, 4),
            (2, .push, "Push performance", 59, 14_760, 7, 2),
            (4, .upper, "Upper performance", 54, 12_980, 7, 3),
            (5, .legs, "Legs performance", 65, 18_210, 8, 4),
            (6, .pull, "Pull performance", 57, 13_860, 7, 2)
        ]
        return sessions.compactMap { offset, focus, title, minutes, volume, rpe, soreness in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { return nil }
            return WorkoutLog(planTitle: title, focus: focus, date: date, durationMinutes: minutes, volume: volume, rpe: rpe, soreness: soreness, completion: 1)
        }
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
}

private struct SavedWorkoutState: Codable { var profile: CoachingProfile; var recommendedWorkout: WorkoutPlan; var workoutHistory: [WorkoutLog] }
private struct RemoteExercise: Codable { let name: String; let sets: Int; let reps: String; let load: String; let restSeconds: Int }
private struct RemotePlan: Codable {
    let id: UUID; let title: String; let focus: String; let estimatedMinutes: Int; let intensityNote: String; let exercises: [RemoteExercise]; let rationale: String
    func asWorkoutPlan() throws -> WorkoutPlan { guard let workoutFocus = WorkoutFocus(rawValue: focus.capitalized) else { throw TenxBackendError.invalidResponse }; return WorkoutPlan(id: id, title: title, focus: workoutFocus, estimatedMinutes: estimatedMinutes, intensityNote: intensityNote, exercises: exercises.map { Exercise(name: $0.name, sets: $0.sets, reps: $0.reps, load: $0.load, restSeconds: $0.restSeconds) }, rationale: rationale) }
}
private struct RemoteHistory: Codable { let items: [RemoteLog] }
private struct RemoteLog: Codable { let id: UUID; let planTitle: String; let focus: String; let completedAt: Date; let durationMinutes: Int; let volumeKg: Int; let rpe: Int; let soreness: Int; let completedSets: Int; let prescribedSets: Int; func asWorkoutLog() throws -> WorkoutLog { guard let workoutFocus = WorkoutFocus(rawValue: focus.capitalized) else { throw TenxBackendError.invalidResponse }; return WorkoutLog(id: id, planTitle: planTitle, focus: workoutFocus, date: completedAt, durationMinutes: durationMinutes, volume: volumeKg, rpe: rpe, soreness: soreness, completion: Double(completedSets) / Double(max(prescribedSets, 1))) } }
private struct RemoteProfile: Codable { let goal: String; let daysPerWeek: Int; let equipment: String; func asProfile(using current: CoachingProfile) -> CoachingProfile { CoachingProfile(goal: goal == "strength" ? .strength : .hypertrophy, daysPerWeek: daysPerWeek, equipment: equipment, reminderHour: current.reminderHour, reminderMinute: current.reminderMinute) } }
private struct RemoteProfileUpdate: Codable { let goal: String; let daysPerWeek: Int; let equipment: String }
private struct CompletionPayload: Codable { let planID: UUID; let durationMinutes: Int; let volumeKg: Int; let rpe: Int; let soreness: Int; let completedSets: Int }
private struct CompletionResponse: Codable { let nextPlan: RemotePlan }
private struct ExportSummary: Codable { let profile: CoachingProfile; let workouts: [WorkoutLog] }
private extension JSONDecoder { static var tenxDecoder: JSONDecoder { let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .iso8601; return decoder } }
private extension JSONEncoder { static var tenxEncoder: JSONEncoder { let encoder = JSONEncoder(); encoder.keyEncodingStrategy = .convertToSnakeCase; encoder.dateEncodingStrategy = .iso8601; return encoder } }
