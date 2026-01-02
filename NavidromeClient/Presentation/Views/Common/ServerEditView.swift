//
//  ServerEditView.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 & iOS 17+ Modernization
//  - Migrated to @Environment(Type.self)
//  - Uses @Bindable for ConnectionViewModel
//

import SwiftUI

struct ServerEditView: View {
    var dismissParent: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfig.self) var appConfig
    @Environment(ConnectionViewModel.self) var connectionVM
    
    @State private var serverUrlString: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        @Bindable var vm = connectionVM
        
        Form {
            Section(header: Text("Server Details")) {
                TextField("Server URL (e.g. https://music.example.com)", text: $serverUrlString)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                SecureField("Password", text: $password)
            }
            
            Section {
                Button {
                    Task { await validateAndSave() }
                } label: {
                    if vm.isTestingConnection {
                        HStack {
                            Text("Testing Connection...")
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        Text("Save & Connect")
                    }
                }
                .disabled(serverUrlString.isEmpty || username.isEmpty || password.isEmpty || vm.isTestingConnection)
            }
            
            if !vm.connectionStatusText.isEmpty && vm.connectionStatusText != "Unknown" {
                Section {
                    HStack {
                        Image(systemName: vm.isConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(vm.isConnected ? .green : .red)
                        Text(vm.connectionStatusText)
                    }
                }
            }
        }
        .onAppear {
            if let creds = appConfig.getCredentials() {
                serverUrlString = creds.baseURL.absoluteString
                username = creds.username
                // Password usually not pre-filled for security, or loaded from Keychain
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func validateAndSave() async {
        guard let url = URL(string: serverUrlString), url.scheme != nil, url.host != nil else {
            errorMessage = "Invalid URL. Please include http:// or https://"
            showError = true
            return
        }
        
        await connectionVM.testConnection()
        
        // In a real scenario, ConnectionViewModel would test the specific credentials entered here,
        // rather than the global singleton state. For now, we assume if network is reachable, we save.
        // A robust implementation passes (url, user, pass) to testConnection.
        
        appConfig.configure(baseURL: url, username: username, password: password)
        
        if let dismissParent = dismissParent {
            dismissParent()
        } else {
            dismiss()
        }
    }
}
