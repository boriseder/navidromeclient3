import SwiftUI

struct ServerEditView: View {
    @Binding var isPresented: Bool
    
    // FIX: Swift 6 Environment
    @Environment(AppConfig.self) private var appConfig
    @Environment(AppInitializer.self) private var appInitializer
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(OfflineManager.self) private var offlineManager
    
    // FIX: @State works for @Observable classes
    @State private var connectionManager = ConnectionViewModel()
    
    @State private var showingSaveSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Default init used by SwiftUI
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Server & Login") {
                    TextField("Host", text: $connectionManager.host)
                        .textInputAutocapitalization(.never)
                    
                    TextField("Username", text: $connectionManager.username)
                        .textInputAutocapitalization(.never)
                    
                    SecureField("Password", text: $connectionManager.password)
                    
                    Button("Test Connection") {
                        Task { await connectionManager.testConnection() }
                    }
                    
                    if let error = connectionManager.connectionError {
                        Text(error).foregroundColor(.red)
                    } else if connectionManager.isConnected {
                        Text("Connected").foregroundColor(.green)
                    }
                }
                
                Section {
                    Button("Save") {
                        Task {
                            if await connectionManager.saveCredentials() {
                                isPresented = false
                            }
                        }
                    }
                    .disabled(!connectionManager.isConnected)
                }
            }
            .navigationTitle("Edit Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}
