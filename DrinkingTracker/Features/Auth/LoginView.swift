import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage: String? = nil
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                // Logo / Header
                VStack(spacing: 8) {
                    Text("🍺")
                        .font(.system(size: 64))
                    Text("Drinking Tracker")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("Harm reduction, powered by data")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }

                // Form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 32)

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        Task { await isSignUp ? signUp() : signIn() }
                    } label: {
                        if isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 32)
                    .disabled(isLoading)

                    Button {
                        isSignUp.toggle()
                        errorMessage = nil
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign In" : "No account? Create one")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
    }

    // MARK: - Firebase Auth

    private func signIn() async {
        isLoading = true
        errorMessage = nil
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func signUp() async {
        isLoading = true
        errorMessage = nil
        do {
            try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
