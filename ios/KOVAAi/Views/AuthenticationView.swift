import SwiftUI

struct AuthenticationView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var email = ""
    @State private var password = ""
    @State private var createAccount = false
    @State private var errorText: String?
    @State private var isSubmitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: KOVATokens.xl) {
            Spacer()
            Text("Your training, saved.")
                .font(KOVATokens.displayFont)
                .foregroundStyle(KOVATokens.text)
            Text("Sign in to keep your coaching plan, completed workouts, and progress in sync.")
                .font(KOVATokens.bodyFont)
                .foregroundStyle(KOVATokens.secondaryText)
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            if let errorText {
                Text(errorText)
                    .font(KOVATokens.captionFont)
                    .foregroundStyle(KOVATokens.secondaryText)
            }
            Button(createAccount ? "Create account" : "Sign in") { submit() }
                .buttonStyle(KOVAPrimaryButtonStyle())
                .disabled(isSubmitting || email.isEmpty || password.count < 8)
            Button(createAccount ? "I already have an account" : "Create a new account") { createAccount.toggle() }
                .font(KOVATokens.headlineFont)
                .foregroundStyle(KOVATokens.text)
                .frame(maxWidth: .infinity, minHeight: KOVATokens.iconTarget)
            Spacer()
        }
        .padding(KOVATokens.screenMargin)
        .background(KOVATokens.background)
    }

    private func submit() {
        isSubmitting = true
        errorText = nil
        Task {
            do {
                try await store.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, createAccount: createAccount)
            } catch {
                errorText = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

#Preview {
    AuthenticationView().environment(WorkoutStore()).preferredColorScheme(.dark)
}
