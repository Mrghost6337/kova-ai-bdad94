import SwiftUI

struct AuthenticationView: View {
    @Environment(WorkoutStore.self) private var store
    let onAuthenticated: (() -> Void)?
    @State private var email = ""
    @State private var password = ""
    @State private var createAccount = true
    @State private var errorText: String?
    @State private var isSubmitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: KOVATokens.xl) {
            Spacer()
            Text(createAccount ? "Save your coaching" : "Welcome back")
                .font(KOVATokens.displayFont)
                .foregroundStyle(KOVATokens.text)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(createAccount ? "Create an account to keep your plan, workout history, and adaptive coaching in sync." : "Sign in to continue with your saved coaching plan.")
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
            Button(createAccount ? "Create account" : "Sign in") {
                submit()
            }
            .buttonStyle(KOVAPrimaryButtonStyle())
            .disabled(isSubmitting || email.isEmpty || password.count < 8)
            Button(createAccount ? "I already have an account" : "Create a new account") {
                createAccount.toggle()
                errorText = nil
            }
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
        let submittedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let submittedPassword = password
        Task {
            do {
                try await store.signIn(email: submittedEmail, password: submittedPassword, createAccount: createAccount)
                onAuthenticated?()
            } catch {
                errorText = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

#Preview {
    AuthenticationView(onAuthenticated: nil)
        .environment(WorkoutStore())
        .preferredColorScheme(.dark)
}
