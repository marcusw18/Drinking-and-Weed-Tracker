import SwiftUI
import FirebaseAuth
import AuthenticationServices
import CryptoKit
import GoogleSignIn
import GoogleSignInSwift

struct LoginView: View {
    @Environment(AppState.self) private var appState

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var isSignUp: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var appleNonce: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: - Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(isSignUp ? "Sign up" : "Sign in")
                        .font(AppTheme.Fonts.title(36))
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    HStack(spacing: 4) {
                        Text(isSignUp ? "Already have an account?" : "New user?")
                            .font(AppTheme.Fonts.mono(14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Button(isSignUp ? "Sign in" : "Create an account") {
                            isSignUp.toggle()
                            errorMessage = nil
                        }
                        .font(AppTheme.Fonts.mono(14, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, 24)

                // MARK: - Form Fields
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .frame(width: 20)
                        TextField("Email Address", text: $email)
                            .font(AppTheme.Fonts.mono(14))
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .background(AppTheme.Colors.inputBackground)
                    .cornerRadius(AppTheme.Radius.field)

                    HStack(spacing: 12) {
                        Image(systemName: "lock")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .frame(width: 20)
                        if isPasswordVisible {
                            TextField("Password", text: $password)
                                .font(AppTheme.Fonts.mono(14))
                        } else {
                            SecureField("Password", text: $password)
                                .font(AppTheme.Fonts.mono(14))
                        }
                        Button { isPasswordVisible.toggle() } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .background(AppTheme.Colors.inputBackground)
                    .cornerRadius(AppTheme.Radius.field)
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)

                // MARK: - Error / Info Message
                if let message = errorMessage {
                    Text(message)
                        .font(AppTheme.Fonts.mono(13))
                        .foregroundColor(message.contains("sent") ? .green : .red)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                // MARK: - Forgot Password (sign-in only)
                if !isSignUp {
                    Button("Forgot Password?") { forgotPassword() }
                        .font(AppTheme.Fonts.mono(13))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                }

                // MARK: - Primary Button
                Button {
                    isSignUp ? signUp() : signIn()
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(AppTheme.Colors.accentWhite)
                        } else {
                            Text(isSignUp ? "Create Account" : "Login")
                                .font(AppTheme.Fonts.mono(16, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.accentWhite)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppTheme.Colors.accentBlack)
                    .cornerRadius(AppTheme.Radius.button)
                }
                .disabled(isLoading)
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // MARK: - Divider
                HStack {
                    Rectangle().fill(AppTheme.Colors.divider).frame(height: 1)
                    Text("or")
                        .font(AppTheme.Fonts.mono(13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .padding(.horizontal, 12)
                    Rectangle().fill(AppTheme.Colors.divider).frame(height: 1)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)

                // MARK: - Social Buttons
                VStack(spacing: 14) {

                    // Continue with Google
                    Button { signInWithGoogle() } label: {
                        HStack(spacing: 12) {
                            GoogleLogoView().frame(width: 20, height: 20)
                            Text("Continue with Google")
                                .font(AppTheme.Fonts.mono(15))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.Colors.inputBackground)
                        .cornerRadius(AppTheme.Radius.field)
                    }

                    // Continue with Apple
                    SignInWithAppleButton(.continue) { request in
                        appleNonce = randomNonceString()
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(appleNonce)
                    } onCompletion: { result in
                        handleAppleSignIn(result: result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .cornerRadius(AppTheme.Radius.field)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer(minLength: 40)
            }
        }
        .background(AppTheme.Colors.background)
        .ignoresSafeArea()
    }

    // MARK: - Email / Password

    private func signIn() {
        guard validate() else { return }
        isLoading = true
        errorMessage = nil
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            isLoading = false
            errorMessage = error?.localizedDescription
        }
    }

    private func signUp() {
        guard validate() else { return }
        isLoading = true
        errorMessage = nil
        Auth.auth().createUser(withEmail: email, password: password) { _, error in
            isLoading = false
            errorMessage = error?.localizedDescription
        }
    }

    private func forgotPassword() {
        guard !email.isEmpty else {
            errorMessage = "Enter your email above first."
            return
        }
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error {
                errorMessage = error.localizedDescription
            } else {
                errorMessage = "Password reset email sent."
            }
        }
    }

    private func validate() -> Bool {
        if email.isEmpty || password.isEmpty {
            errorMessage = "Please enter your email and password."
            return false
        }
        return true
    }

    // MARK: - Google Sign-In

    private func signInWithGoogle() {
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows
            .first?.rootViewController
        else {
            errorMessage = "Unable to present Google Sign-In."
            return
        }
        isLoading = true
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            if let error {
                isLoading = false
                let nsError = error as NSError
                if nsError.code != GIDSignInError.canceled.rawValue {
                    errorMessage = error.localizedDescription
                }
                return
            }
            guard
                let user = result?.user,
                let idToken = user.idToken?.tokenString
            else {
                isLoading = false
                errorMessage = "Google Sign-In failed."
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            Auth.auth().signIn(with: credential) { _, error in
                isLoading = false
                errorMessage = error?.localizedDescription
            }
        }
    }

    // MARK: - Apple Sign-In

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let token = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "Apple Sign-In failed. Please try again."
                return
            }
            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: token,
                rawNonce: appleNonce,
                fullName: credential.fullName
            )
            isLoading = true
            Auth.auth().signIn(with: firebaseCredential) { _, error in
                isLoading = false
                errorMessage = error?.localizedDescription
            }
        case .failure(let error):
            let nsError = error as NSError
            if nsError.code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        return randomBytes.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Google Logo
struct GoogleLogoView: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = size.width / 2

            var bluePath = Path()
            bluePath.addArc(center: center, radius: radius, startAngle: .degrees(-30), endAngle: .degrees(90), clockwise: false)
            bluePath.addLine(to: center); bluePath.closeSubpath()
            context.fill(bluePath, with: .color(Color(red: 0.26, green: 0.52, blue: 0.96)))

            var greenPath = Path()
            greenPath.addArc(center: center, radius: radius, startAngle: .degrees(90), endAngle: .degrees(210), clockwise: false)
            greenPath.addLine(to: center); greenPath.closeSubpath()
            context.fill(greenPath, with: .color(Color(red: 0.23, green: 0.73, blue: 0.33)))

            var yellowPath = Path()
            yellowPath.addArc(center: center, radius: radius, startAngle: .degrees(210), endAngle: .degrees(330), clockwise: false)
            yellowPath.addLine(to: center); yellowPath.closeSubpath()
            context.fill(yellowPath, with: .color(Color(red: 0.98, green: 0.73, blue: 0.02)))

            var redPath = Path()
            redPath.addArc(center: center, radius: radius, startAngle: .degrees(330), endAngle: .degrees(390), clockwise: false)
            redPath.addLine(to: center); redPath.closeSubpath()
            context.fill(redPath, with: .color(Color(red: 0.92, green: 0.26, blue: 0.21)))

            let innerRadius = radius * 0.65
            var innerCircle = Path()
            innerCircle.addEllipse(in: CGRect(x: center.x - innerRadius, y: center.y - innerRadius, width: innerRadius * 2, height: innerRadius * 2))
            context.fill(innerCircle, with: .color(.white))

            let barHeight = radius * 0.28
            let barRect = CGRect(x: center.x - radius * 0.05, y: center.y - barHeight / 2, width: radius * 1.05, height: barHeight)
            context.fill(Path(roundedRect: barRect, cornerRadius: barHeight / 2), with: .color(Color(red: 0.26, green: 0.52, blue: 0.96)))
        }
    }
}

#Preview {
    LoginView().environment(AppState())
}
