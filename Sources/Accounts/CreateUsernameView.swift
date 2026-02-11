import SwiftUI

struct CreateUsernameView: View {
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var username: String = ""
    @State private var errorMessage: String?
    @State private var showDuplicateError = false
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Create Username")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text("Choose a unique username (3–16 characters). Letters, numbers, underscore only.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            TextField("Username", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 24)

            if showDuplicateError {
                Text("error: user already exists.")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(8)
                    .padding(.horizontal, 24)
            }

            if let errorMessage, !showDuplicateError {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button(action: { submit() }) {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Confirm")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .interactiveDismissDisabled(true)
    }

    private func submit() {
        let value = username.trimmingCharacters(in: .whitespacesAndNewlines)
        showDuplicateError = false
        errorMessage = nil
        isSubmitting = true

        Task {
            do {
                try await accountManager.claimUsername(value)
                isSubmitting = false
            } catch let error as UsernameClaimError {
                isSubmitting = false
                switch error {
                case .duplicate:
                    showDuplicateError = true
                case .invalid:
                    errorMessage = "Username must be 3–16 characters with letters, numbers, or underscore."
                case .notSignedIn:
                    errorMessage = "Please sign in with Apple first."
                case .cloud:
                    errorMessage = "Could not claim username. Try again."
                }
            } catch {
                isSubmitting = false
                errorMessage = "Could not claim username. Try again."
            }
        }
    }
}
