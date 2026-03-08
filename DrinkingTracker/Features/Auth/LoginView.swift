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
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)

                    HStack(spacing: 4) {
                        Text(isSignUp ? "Already have an account?" : "New user?")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.gray)
                        Button(isSignUp ? "Sign in" : "Create an account") {
                            isSignUp.toggle()
                            errorMessage = nil
                        }
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, 24)

                // MARK: - Form Fields
                VStack(spacing: 12) {

                    // Email Field
                    HStack(spacing: 12) {
                        Image(systemName: "envelope")
                            .foregroundColor(.gray)
                            .frame(width: 20)
                        TextField("Email Address", text: $email)
                            .font(.system(size: 14, design: .monospaced))
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                    // Password Field
                    HStack(spacing: 12) {
                        Image(systemName: "lock")
                            .foregroundColor(.gray)
                            .frame(width: 20)
                        if isPasswordVisible {
                            TextField("Password", text: $password)
                                .font(.system(size: 14, design: .monospaced))
                        } else {
                            SecureField("Password", text: $password)
                                .font(.system(size: 14, design: .monospaced))
                        }
                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)

                // MARK: - Error / Info Message
                if let message = errorMessage {
                    Text(message)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(message.contains("sent") ? .green : .red)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                // MARK: - Forgot Password (sign-in only)
                if !isSignUp {
                    Button("Forgot Password?") {
                        forgotPassword()
                    }
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                }

                // MARK: - Primary Button
                Button {
                    isSignUp ? signUp() : signIn()
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(isSignUp ? "Create Account" : "Login")
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // MARK: - Divider
                HStack {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                    Text("or")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 12)
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)

                // MARK: - Social Buttons
                VStack(spacing: 14) {

                    // Continue with Google
                    Button {
                        signInWithGoogle()
                    } label: {
                        HStack(spacing: 12) {
                            GoogleLogoView()
                                .frame(width: 20, height: 20)
                            Text("Continue with Google")
                                .font(.system(size: 15, design: .monospaced))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
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
                    .cornerRadius(10)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer(minLength: 40)
            }
        }
        .background(Color.white)
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
            // ASAuthorizationError.canceled (code 1001) means user dismissed — don't show error
            let nsError = error as NSError
            if nsError.code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
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

    // MARK: - Nonce Helpers (required for Apple Sign-In with Firebase)

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

// MARK: - Google Logo (drawn with SwiftUI shapes)
struct GoogleLogoView: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = size.width / 2

            // Blue arc (top-right)
            var bluePath = Path()
            bluePath.addArc(center: center, radius: radius,
                            startAngle: .degrees(-30), endAngle: .degrees(90), clockwise: false)
            bluePath.addLine(to: center)
            bluePath.closeSubpath()
            context.fill(bluePath, with: .color(Color(red: 0.26, green: 0.52, blue: 0.96)))

            // Green arc (bottom-right)
            var greenPath = Path()
            greenPath.addArc(center: center, radius: radius,
                             startAngle: .degrees(90), endAngle: .degrees(210), clockwise: false)
            greenPath.addLine(to: center)
            greenPath.closeSubpath()
            context.fill(greenPath, with: .color(Color(red: 0.23, green: 0.73, blue: 0.33)))

            // Yellow arc (bottom-left)
            var yellowPath = Path()
            yellowPath.addArc(center: center, radius: radius,
                              startAngle: .degrees(210), endAngle: .degrees(330), clockwise: false)
            yellowPath.addLine(to: center)
            yellowPath.closeSubpath()
            context.fill(yellowPath, with: .color(Color(red: 0.98, green: 0.73, blue: 0.02)))

            // Red arc (top-left)
            var redPath = Path()
            redPath.addArc(center: center, radius: radius,
                           startAngle: .degrees(330), endAngle: .degrees(330 + 60), clockwise: false)
            redPath.addLine(to: center)
            redPath.closeSubpath()
            context.fill(redPath, with: .color(Color(red: 0.92, green: 0.26, blue: 0.21)))

            // White inner circle
            let innerRadius = radius * 0.65
            var innerCircle = Path()
            innerCircle.addEllipse(in: CGRect(
                x: center.x - innerRadius,
                y: center.y - innerRadius,
                width: innerRadius * 2,
                height: innerRadius * 2
            ))
            context.fill(innerCircle, with: .color(.white))

            // Blue G bar (horizontal cutout)
            let barHeight = radius * 0.28
            let barRect = CGRect(
                x: center.x - radius * 0.05,
                y: center.y - barHeight / 2,
                width: radius * 1.05,
                height: barHeight
            )
            let barPath = Path(roundedRect: barRect, cornerRadius: barHeight / 2)
            context.fill(barPath, with: .color(Color(red: 0.26, green: 0.52, blue: 0.96)))
        }
    }
}

#Preview {
    LoginView()
        .environment(AppState())
}
