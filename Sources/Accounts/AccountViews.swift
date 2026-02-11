import SwiftUI
import AuthenticationServices

struct AccountStatusView: View {
    @ObservedObject private var accountManager = AccountManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Account")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text(accountManager.isSignedIn ? "Signed In" : "Guest")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            if accountManager.isSignedIn {
                Text("User ID: \(accountManager.state.userId)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Button("Sign Out") {
                    accountManager.signOut()
                }
                .buttonStyle(.bordered)
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = []
                } onCompletion: { result in
                    accountManager.handleSignIn(result: result)
                }
                .frame(height: 44)
            }
        }
        .padding(.vertical, 4)
    }
}
