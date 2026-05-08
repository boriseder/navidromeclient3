//
//  ServerEditView.swift
//  NavidromeClient
//
//  Rewritten for clarity and non-technical users.
//  - Split URL: scheme picker + host + port
//  - Separate "Test" and "Save" steps
//  - Inline validation and connection feedback
//  - Password show/hide toggle
//

import SwiftUI
import Observation

struct ServerEditView: View {
    var dismissParent: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfig.self) var appConfig
    @Environment(ConnectionViewModel.self) var connectionVM

    // MARK: - Field State
    @State private var scheme: URLScheme = .https
    @State private var host: String = ""
    @State private var port: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false

    // MARK: - Flow State
    @State private var connectionResult: ConnectionResult? = nil
    @State private var isTesting: Bool = false
    @State private var isSaving: Bool = false
    @State private var hostError: String? = nil
    @State private var credentialsError: String? = nil

    enum URLScheme: String, CaseIterable {
        case https, http
        var prefix: String { rawValue + "://" }
        var isSecure: Bool { self == .https }
    }

    enum ConnectionResult {
        case success
        case failure(String)

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    // MARK: - Computed

    private var builtURL: URL? {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else { return nil }
        let portPart = port.isEmpty ? "" : ":\(port)"
        return URL(string: "\(scheme.prefix)\(trimmedHost)\(portPart)")
    }

    private var canTest: Bool {
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.isEmpty &&
        !password.isEmpty &&
        !isTesting
    }

    private var canSave: Bool {
        connectionResult?.isSuccess == true && !isSaving
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                headerView
                serverFieldsSection
                credentialsSection
                connectionStatusView
                actionButtons
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(appConfig.getCredentials() != nil ? "Edit Server" : "Server Setup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: prefillExistingCredentials)
        .onChange(of: host) { _, _ in resetConnectionResult() }
        .onChange(of: port) { _, _ in resetConnectionResult() }
        .onChange(of: scheme) { _, _ in resetConnectionResult() }
        .onChange(of: username) { _, _ in resetConnectionResult() }
        .onChange(of: password) { _, _ in resetConnectionResult() }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: "server.rack")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.top, 8)

            Text("Connect to Navidrome")
                .font(.title3.weight(.semibold))

            Text("Enter your server address and login details.\nNot sure? Ask whoever set up your music server.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Server Fields

    private var serverFieldsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Server Address", systemImage: "network")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                // Scheme row
                HStack(spacing: 0) {
                    Text("Protocol")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Picker("", selection: $scheme) {
                        ForEach(URLScheme.allCases, id: \.self) { s in
                            Text(s.rawValue.uppercased()).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if !scheme.isSecure {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("HTTP sends your password unencrypted. Use HTTPS if possible.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Divider().padding(.leading, 16)

                // Host row
                VStack(alignment: .leading, spacing: 4) {
                    ServerTextField(
                        placeholder: "music.example.com",
                        text: $host,
                        keyboardType: .URL,
                        autocapitalization: .never
                    )
                    if let err = hostError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                            .transition(.opacity)
                    }
                }

                Divider().padding(.leading, 16)

                // Port row
                HStack {
                    ServerTextField(
                        placeholder: "Port (optional, e.g. 4533)",
                        text: $port,
                        keyboardType: .numberPad,
                        autocapitalization: .never
                    )
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("The address of your Navidrome server. Include the port if it's not on a standard port — Navidrome typically uses 4533.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
        .animation(.easeInOut(duration: 0.2), value: scheme)
        .animation(.easeInOut(duration: 0.15), value: hostError)
    }

    // MARK: - Credentials

    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Login", systemImage: "person.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ServerTextField(
                    placeholder: "Username",
                    text: $username,
                    keyboardType: .default,
                    autocapitalization: .never
                )

                Divider().padding(.leading, 16)

                // Password with show/hide
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
                    .padding(.vertical, 13)
                    .padding(.leading, 16)

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 16)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if let err = credentialsError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.15), value: credentialsError)
            }
        }
    }

    // MARK: - Connection Status

    @ViewBuilder
    private var connectionStatusView: some View {
        if let result = connectionResult {
            HStack(spacing: 10) {
                Image(systemName: result.isSuccess
                    ? "checkmark.circle.fill"
                    : "xmark.circle.fill"
                )
                .font(.system(size: 18))
                .foregroundStyle(result.isSuccess ? .green : .red)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.isSuccess ? "Connection successful" : "Connection failed")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(result.isSuccess ? .green : .red)

                    if case .failure(let msg) = result {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Your server is reachable and credentials are valid.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(result.isSuccess
                          ? Color.green.opacity(0.08)
                          : Color.red.opacity(0.08)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(result.isSuccess
                                    ? Color.green.opacity(0.25)
                                    : Color.red.opacity(0.25),
                                    lineWidth: 1)
                    )
            )
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Test Connection
            Button {
                Task { await testConnection() }
            } label: {
                HStack(spacing: 8) {
                    if isTesting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.85)
                            .tint(.white)
                        Text("Testing…")
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Test Connection")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canTest ? Color.accentColor : Color.accentColor.opacity(0.35))
                )
            }
            .disabled(!canTest)
            .animation(.easeInOut(duration: 0.15), value: canTest)

            // Save — only enabled after successful test
            Button {
                Task { await save() }
            } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.85)
                            .tint(canSave ? .accentColor : .secondary)
                        Text("Saving…")
                    } else {
                        Image(systemName: "checkmark")
                        Text("Save & Connect")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(canSave ? Color.accentColor : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(canSave
                                        ? Color.accentColor.opacity(0.5)
                                        : Color(.separator),
                                        lineWidth: 1)
                        )
                )
            }
            .disabled(!canSave)
            .animation(.easeInOut(duration: 0.15), value: canSave)

            if !canSave && connectionResult == nil {
                Text("Test the connection first, then save.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: connectionResult?.isSuccess)
    }

    // MARK: - Logic

    private func prefillExistingCredentials() {
        guard let creds = appConfig.getCredentials() else { return }
        let url = creds.baseURL
        scheme = url.scheme == "https" ? .https : .http
        host = url.host ?? ""
        if let p = url.port { port = String(p) }
        username = creds.username
        // Password intentionally not prefilled — user must re-enter to confirm
    }

    private func resetConnectionResult() {
        guard connectionResult != nil else { return }
        withAnimation { connectionResult = nil }
    }

    private func testConnection() async {
        hostError = nil
        credentialsError = nil

        // Validate host
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
                    ? "Check your server address and credentials."
                    : connectionVM.connectionStatusText
                connectionResult = .failure(msg)
            }
        }
    }

    private func save() async {
        guard let url = builtURL, connectionResult?.isSuccess == true else { return }
        isSaving = true
        defer { isSaving = false }

        appConfig.configure(baseURL: url, username: username, password: password)

        if let dismissParent {
            dismissParent()
        } else {
            dismiss()
        }
    }
}

// MARK: - ServerTextField

/// Consistent text field used inside the grouped card rows.
private struct ServerTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled()
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
    }
}
