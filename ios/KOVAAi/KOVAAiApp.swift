import SwiftUI

@main
struct KOVAAiApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
            Text("Your app is ready.")
                .font(.title)
                .fontWeight(.semibold)
            Text("Ask 10x to start building.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
