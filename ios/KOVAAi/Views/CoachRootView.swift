import SwiftUI

struct CoachRootView: View {
    @AppStorage("kova.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var store = WorkoutStore()
    @State private var showingSettings = false
    @State private var showingOnboarding = false

    var body: some View {
        TabView {
            NavigationStack {
                TodayView(showSettings: $showingSettings)
            }
            .tabItem { Label("Coach", systemImage: "figure.strengthtraining.traditional") }

            NavigationStack {
                HistoryView()
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            NavigationStack {
                PlanView()
            }
            .tabItem { Label("Plan", systemImage: "calendar") }
        }
        .task { await store.restoreSession() }
        .tint(KOVATokens.accent)
        .environment(store)
        .preferredColorScheme(.dark)
        .overlay {
            if !hasCompletedOnboarding {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
                .environment(store)
                .preferredColorScheme(.dark)
            } else if !store.isAuthenticated {
                AuthenticationView()
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView(showOnboarding: $showingOnboarding)
            }
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView {
                hasCompletedOnboarding = true
                showingOnboarding = false
            }
            .environment(store)
            .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    CoachRootView()
}
