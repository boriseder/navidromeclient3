//
//  ServerEditView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 24.09.25.
//



import SwiftUI

struct ServerEditView: View {
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var appInitializer: AppInitializer
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var connectionManager = ConnectionViewModel()
    @State private var showingSaveSuccess = false
    @State private var showingError = false
    @State private var showingOfflineWarning = false
    @State private var errorMessage = ""
    @State private var isWaitingForServices = false
    
    let dismissParent: (() -> Void)?
    
    init(dismissParent: (() -> Void)? = nil) {
        self.dismissParent = dismissParent
    }
    
    var body: some View {
        Form {
            if offlineManager.isOfflineMode || !networkMonitor.shouldLoadOnlineContent {
                OfflineWarningSection()
            }
            
            Section("Server & Login") {
                Picker("Protocol", selection: $connectionManager.scheme) {
                    Text("http").tag("http")
                    Text("https").tag("https")
                }.pickerStyle(.segmented)

                TextField("Host", text: $connectionManager.host)
                    .textInputAutocapitalization(.none)
                    .disableAutocorrection(true)
                TextField("Port", text: $connectionManager.port)
                    .keyboardType(.numberPad)
                TextField("Username", text: $connectionManager.username)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                SecureField("Password", text: $connectionManager.password)

                ConnectionStatusView(connectionManager: connectionManager)

                Button("Test Connection") {
                    Task { await testConnectionWithOfflineCheck() }
                }
                //.disabled(!connectionManager.canTestConnection ||
                         //(offlineManager.isOfflineMode && !networkMonitor.canLoadOnlineContent))
            }

            Section {
                Button {
                    Task { await saveCredentialsAndConfigure() }
                } label: {
                    HStack {
                        if isWaitingForServices {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Initializing services...")
                        } else {
                            Text("Save & Continue")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(!connectionManager.isConnected || isWaitingForServices)
            }
        }
        .navigationTitle(appInitializer.isConfigured ? "Edit Server" : "Initial Setup")
        .onAppear {
            //loadExistingCredentials()
            if connectionManager.canTestConnection {
                Task { await testConnectionWithOfflineCheck() }
            }

        }
        .alert("Success", isPresented: $showingSaveSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Configuration saved successfully")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Switch to Online Mode?", isPresented: $showingOfflineWarning) {
            Button("Switch to Online") {
                offlineManager.switchToOnlineMode()
                Task { await connectionManager.testConnection() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You need to be in online mode to test the server connection.")
        }
    }
    
    // MARK: - Actions
    
    private func loadExistingCredentials() {
        if let creds = AppConfig.shared.getCredentials() {
            connectionManager.scheme = creds.baseURL.scheme ?? "http"
            connectionManager.host = creds.baseURL.host ?? ""
            connectionManager.port = creds.baseURL.port.map { String($0) } ?? ""
            connectionManager.username = creds.username
            connectionManager.password = creds.password
        }
    }
    
    private func saveCredentialsAndConfigure() async {
        let success = await connectionManager.saveCredentials()
        if success {

            await MainActor.run {
                isWaitingForServices = true

            }

            // Wait for services to initialize (max 5 seconds)
            for attempt in 0..<10 {
                
                if appInitializer.areServicesReady {
                    await MainActor.run {
                        isWaitingForServices = false
                        dismiss()
                        dismissParent?()  // Dismiss parent if initial setup
                    }
                    return
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }

            // Timeout
            await MainActor.run {
                isWaitingForServices = false
                errorMessage = "Services failed to initialize. Please try again."
                showingError = true
            }
        } else {
            errorMessage = connectionManager.connectionError ?? "Failed to save credentials"
            showingError = true
        }
    }

    private func testConnectionWithOfflineCheck() async {
        if offlineManager.isOfflineMode || !networkMonitor.shouldLoadOnlineContent {
            showingOfflineWarning = true
            return
        }
        await connectionManager.testConnection()
    }
}

// MARK: - Supporting Views

struct ConnectionStatusView: View {
    @ObservedObject var connectionManager: ConnectionViewModel

    var body: some View {
        HStack {
            Text("Connection:")
            Spacer()
            if connectionManager.isTestingConnection {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: connectionManager.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(connectionManager.isConnected ? .green : .red)
                Text(connectionManager.connectionStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct OfflineWarningSection: View {
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    
    var body: some View {
        Section {
            HStack {
                Image(systemName: offlineManager.isOfflineMode ? "icloud.slash" : "wifi.slash")
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Offline Mode Active")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(warningText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if networkMonitor.canLoadOnlineContent {
                    Button("Go Online") {
                        offlineManager.switchToOnlineMode()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.orange.opacity(0.1))
    }
    
    private var warningText: String {
        if !networkMonitor.canLoadOnlineContent {
            return "No internet connection available"
        } else if offlineManager.isOfflineMode {
            return "Using downloaded content only"
        } else {
            return "Limited connectivity"
        }
    }
}
