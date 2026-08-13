import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

enum HealthConnectionState: Equatable {
    case unavailable
    case notConnected
    case requesting
    case connected
    case failed(String)

    var title: String {
        switch self {
        case .unavailable:
            return "Unavailable on this device"
        case .notConnected:
            return "Not connected"
        case .requesting:
            return "Requesting access"
        case .connected:
            return "Connected"
        case .failed:
            return "Connection needs attention"
        }
    }

    var detail: String {
        switch self {
        case .unavailable:
            return "Apple Health is available on iPhone."
        case .notConnected:
            return "Use recovery and activity context to refine coaching."
        case .requesting:
            return "Waiting for Apple Health permission."
        case .connected:
            return "KOVA can use permitted activity and workout context."
        case let .failed(message):
            return message
        }
    }
}

enum HealthKitService {
    static func requestWorkoutReadAccess() async -> HealthConnectionState {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        let healthStore = HKHealthStore()
        guard let exerciseMinutes = HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
              let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return .failed("Apple Health data types are unavailable.")
        }
        let workoutType = HKObjectType.workoutType()
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [workoutType, exerciseMinutes, activeEnergy])
            return .connected
        } catch {
            return .failed(error.localizedDescription)
        }
        #else
        return .unavailable
        #endif
    }
}
