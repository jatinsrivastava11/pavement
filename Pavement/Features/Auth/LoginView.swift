import SwiftUI

/// Email and password sign-in / sign-up. Studio will restyle this later.
struct LoginView: View {
    let auth: AuthModel

    private enum Mode: String, CaseIterable {
        case signIn = "Sign In"
        case signUp = "Create Account"
    }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(mode == .signIn ? .password : .newPassword)
                } footer: {
                    if mode == .signUp {
                        Text("At least \(AuthModel.minimumPasswordLength) characters.")
                    }
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
                if let infoMessage {
                    Section { Text(infoMessage).foregroundStyle(.secondary) }
                }

                Section {
                    Button(action: submit) {
                        HStack {
                            Spacer()
                            if isWorking { ProgressView() } else { Text(mode.rawValue).bold() }
                            Spacer()
                        }
                    }
                    .disabled(isWorking)
                }
            }
            .navigationTitle("Pavement")
            .onChange(of: mode) {
                errorMessage = nil
                infoMessage = nil
            }
        }
    }

    private func submit() {
        errorMessage = nil
        infoMessage = nil
        if let problem = AuthModel.validationError(email: email, password: password) {
            errorMessage = problem
            return
        }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                switch mode {
                case .signIn:
                    try await auth.signIn(email: email, password: password)
                case .signUp:
                    if try await auth.signUp(email: email, password: password) == .needsEmailConfirmation {
                        infoMessage = "Check your email for a confirmation link, then sign in."
                        mode = .signIn
                    }
                }
            } catch {
                errorMessage = AuthModel.message(for: error)
            }
        }
    }
}

#Preview {
    LoginView(auth: AuthModel())
}
