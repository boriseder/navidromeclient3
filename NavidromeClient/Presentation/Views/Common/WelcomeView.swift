//
//  WelcomeView.swift
//  NavidromeClient
//
//  Self-contained 3-step setup wizard.
//  Step 1: Welcome
//  Step 2: Server setup (with live connection test)
//  Step 3: Success
//
//  ContentView usage:
//    case .setupRequired:
//        WelcomeView()   ← no callback needed anymore
//

import SwiftUI
import Observation

struct WelcomeView: View {
    // Legacy callback kept for API compatibility — no longer used internally
    var onGetStarted: (() -> Void)? = nil

    @Environment(AppConfig.self) var appConfig
    @Environment(ConnectionViewModel.self) var connectionVM
    @Environment(AppInitializer.self) var appInitializer

    @State private var step: SetupStep = .welcome
    @State private var animateStep: Bool = false

    enum SetupStep: Int, CaseIterable {
        case welcome = 0
        case server  = 1
        case success = 2

        var isFirst: Bool { self == .welcome }
        var isLast:  Bool { self == .success }
    }

    var body: some View {
        ZStack {
            // Shared background across all steps
            DynamicMusicBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots — hidden on welcome and success
                if step == .server {
                    progressDots
                        .padding(.top, 16)
                        .transition(.opacity)
                }

                // Step content
                ZStack {
                    switch step {
                    case .welcome:
                        WelcomeStepView(onNext: advanceTo(.server))
                            .transition(stepTransition)
                    case .server:
                        ServerStepView(onSuccess: advanceTo(.success))
                            .transition(stepTransition)
                    case .success:
                        SuccessStepView()
                            .transition(stepTransition)
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(1..<SetupStep.allCases.count - 1, id: \.self) { index in
                // Only show dots for the "real" steps (server only for now, extensible)
                Circle()
                    .fill(step.rawValue >= index ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .scaleEffect(step.rawValue == index ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3), value: step)
            }
        }
        .padding(.bottom, 8)
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal:   .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advanceTo(_ next: SetupStep) -> () -> Void {
        { withAnimation { step = next } }
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStepView: View {
    let onNext: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(.white.opacity(0.05))
                    .frame(width: 160, height: 160)
                Image(systemName: "music.note.house.fill")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 40)

            // Text
            VStack(spacing: 12) {
                Text("Your music,\nyour server.")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)

                Text("A native client for Navidrome — the self-hosted\nmusic server that puts you in control.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
            }

            Spacer().frame(height: 20)

            // Feature pills
            VStack(spacing: 10) {
                FeaturePill(icon: "arrow.down.circle.fill",  text: "Offline listening — download albums for the road")
                FeaturePill(icon: "waveform",                text: "Gapless playback and full queue control")
                FeaturePill(icon: "heart.fill",              text: "Favorites, genres, artists and albums")
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            Spacer()

            // CTA
            Button(action: onNext) {
                Text("Get Started")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        Capsule().fill(.white)
                    )
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .padding(.horizontal, 28)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }
}

private struct FeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 24)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.75))
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Step 2: Server Setup

private struct ServerStepView: View {
    let onSuccess: () -> Void

    @Environment(AppConfig.self) var appConfig
    @Environment(ConnectionViewModel.self) var connectionVM

    // URL fields
    @State private var scheme: URLScheme = .https
    @State private var host: String = ""
    @State private var port: String = ""

    // Credentials
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false

    // State
    @State private var isTesting: Bool = false
    @State private var connectionResult: ConnectionResult? = nil
    @State private var hostError: String? = nil
    @State private var credentialsError: String? = nil
    @State private var appeared = false

    enum URLScheme: String, CaseIterable {
        case https, http
        var prefix: String { rawValue + "://" }
        var isSecure: Bool { self == .https }
    }

    enum ConnectionResult {
        case success
        case failure(String)
        var isSuccess: Bool { if case .success = self { return true }; return false }
    }

    private var builtURL: URL? {
        let h = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !h.isEmpty else { return nil }
        let portPart = port.isEmpty ? "" : ":\(port)"
        return URL(string: "\(scheme.prefix)\(h)\(portPart)")
    }

    private var canTest: Bool {
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.isEmpty &&
        !password.isEmpty &&
        !isTesting
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {

                // Header
                VStack(spacing: 10) {
                    Text("Connect your server")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Enter the address of your Navidrome server\nand your login details.")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .padding(.top, 12)

                // Server address card
                SetupCard(title: "Server Address", icon: "server.rack") {
                    VStack(spacing: 0) {
                        // Scheme picker
                        HStack {
                            Text("Protocol")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Picker("", selection: $scheme) {
                                ForEach(URLScheme.allCases, id: \.self) {
                                    Text($0.rawValue.uppercased()).tag($0)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if !scheme.isSecure {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                Text("HTTP sends your password unencrypted.")
                                    .font(.caption)
                                Spacer()
                            }
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        DarkDivider()

                        // Host
                        VStack(alignment: .leading, spacing: 4) {
                            DarkTextField(
                                placeholder: "music.example.com",
                                text: $host,
                                keyboardType: .URL
                            )
                            if let err = hostError {
                                Text(err)
                                    .font(.caption)
                                    .foregroundStyle(.red.opacity(0.9))
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 6)
                                    .transition(.opacity)
                            }
                        }

                        DarkDivider()

                        // Port
                        DarkTextField(
                            placeholder: "Port — leave empty for default (4533)",
                            text: $port,
                            keyboardType: .numberPad
                        )
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                // Login card
                SetupCard(title: "Login", icon: "person.circle") {
                    VStack(spacing: 0) {
                        DarkTextField(
                            placeholder: "Username",
                            text: $username
                        )
                        DarkDivider()
                        HStack {
                            Group {
                                if showPassword {
                                    TextField("Password", text: $password)
                                } else {
                                    SecureField("Password", text: $password)
                                }
                            }
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.white)
                            .padding(.vertical, 13)
                            .padding(.leading, 16)

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(.trailing, 16)
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                if let err = credentialsError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.15), value: credentialsError)
                }

                // Connection result
                if let result = connectionResult {
                    connectionResultView(result)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }

                // Connect button
                Button {
                    Task { await testAndConnect() }
                } label: {
                    HStack(spacing: 10) {
                        if isTesting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.85)
                                .tint(.black)
                            Text("Connecting…")
                        } else if connectionResult?.isSuccess == true {
                            Image(systemName: "checkmark")
                            Text("Save & Continue")
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Text("Test & Connect")
                        }
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(canTest ? .black : .white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        Capsule()
                            .fill(canTest ? .white : .white.opacity(0.1))
                    )
                }
                .disabled(!canTest)
                .animation(.easeInOut(duration: 0.15), value: canTest)
                .opacity(appeared ? 1 : 0)

                // What is Navidrome?
                DisclosureGroup {
                    Text("Navidrome is a free, open-source music server you (or a friend) host yourself. It gives you a private streaming service — no subscriptions, no ads, full control. If someone gave you this app, ask them for the server address and your login.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineSpacing(3)
                        .padding(.top, 6)
                } label: {
                    Text("What is Navidrome?")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .tint(.white.opacity(0.4))
                .padding(.bottom, 40)
                .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, 24)
        }
        .onChange(of: host)     { _, _ in resetResult() }
        .onChange(of: port)     { _, _ in resetResult() }
        .onChange(of: scheme)   { _, _ in resetResult() }
        .onChange(of: username) { _, _ in resetResult() }
        .onChange(of: password) { _, _ in resetResult() }
        .animation(.easeInOut(duration: 0.2), value: scheme)
        .animation(.easeInOut(duration: 0.15), value: connectionResult?.isSuccess)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private func connectionResultView(_ result: ConnectionResult) -> some View {
        HStack(spacing: 10) {
            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(result.isSuccess ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.isSuccess ? "Connection successful" : "Connection failed")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(result.isSuccess ? .green : .red)
                if case .failure(let msg) = result {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                } else {
                    Text("Server is reachable and credentials are valid.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(result.isSuccess
                      ? Color.green.opacity(0.1)
                      : Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(result.isSuccess
                                ? Color.green.opacity(0.3)
                                : Color.red.opacity(0.3),
                                lineWidth: 1)
                )
        )
    }

    private func resetResult() {
        guard connectionResult != nil else { return }
        withAnimation { connectionResult = nil }
    }

    private func testAndConnect() async {
        hostError = nil
        credentialsError = nil

        // If already tested successfully, go straight to save
        if connectionResult?.isSuccess == true {
            save()
            return
        }

        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            withAnimation { hostError = "Please enter a server address." }
            return
        }
        guard builtURL != nil else {
            withAnimation { hostError = "That doesn't look like a valid address." }
            return
        }
        guard !username.isEmpty, !password.isEmpty else {
            withAnimation { credentialsError = "Please enter your username and password." }
            return
        }

        isTesting = true
        defer { isTesting = false }

        let success = await connectionVM.testCredentials(
            baseURL: builtURL!,
            username: username,
            password: password
        )

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if success {
                connectionResult = .success
            } else {
                let msg = connectionVM.connectionStatusText.isEmpty
                    ? "Check your address and credentials."
                    : connectionVM.connectionStatusText
                connectionResult = .failure(msg)
            }
        }
    }

    private func save() {
        guard let url = builtURL else { return }
        appConfig.configure(baseURL: url, username: username, password: password)
        // ContentView observes appConfig and will transition automatically
        // but we also advance the wizard step for the success screen
        onSuccess()
    }
}

// MARK: - Step 3: Success

private struct SuccessStepView: View {
    @State private var appeared = false
    @State private var checkScale: CGFloat = 0.3
    @State private var ringOpacity: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated checkmark
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 160, height: 160)
                    .scaleEffect(appeared ? 1.3 : 0.8)
                    .opacity(appeared ? 0 : 0.6)
                    .animation(
                        .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                        value: appeared
                    )

                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(appeared ? 1 : 0.3)
                    .opacity(appeared ? 1 : 0)
            }

            Spacer().frame(height: 44)

            VStack(spacing: 12) {
                Text("You're all set.")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)

                Text("Your library is loading.\nTime to listen.")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
            }

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
        // ContentView will automatically transition to the main TabView
        // once appConfig is configured and services initialize
    }
}

// MARK: - Shared Dark UI Components

private struct SetupCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.8)
            }
            .foregroundStyle(.white.opacity(0.45))
            .padding(.horizontal, 4)
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

private struct DarkTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .foregroundStyle(.white)
            .tint(.white)
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
    }
}

private struct DarkDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, 16)
    }
}
