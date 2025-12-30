//
//  ServerEditView.swift
//  NavidromeClient3
//
//  Swift 6: Added Port Field
//

import SwiftUI
import Observation

struct ServerEditView: View {
    var viewModel: ConnectionViewModel
    
    var body: some View {
        @Bindable var vm = viewModel
        
        Form {
            Section(header: Text("Server Details")) {
                // Combined Row: Protocol | Host | : | Port
                HStack(spacing: 8) {
                    // 1. Protocol Picker
                    Picker("Protocol", selection: $vm.scheme) {
                        ForEach(ServerScheme.allCases) { scheme in
                            Text(scheme.rawValue.uppercased()).tag(scheme)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 80)
                    
                    // 2. Host Field
                    TextField("192.168.x.x", text: $vm.host)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    // 3. Port Separator
                    Text(":")
                        .foregroundColor(.secondary)
                    
                    // 4. Port Field
                    TextField("Port", text: $vm.port)
                        .keyboardType(.numberPad)
                        .frame(width: 60)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                TextField("Username", text: $vm.username)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                SecureField("Password", text: $vm.password)
                    .textContentType(.password)
            }
            
            if let error = vm.errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            Section {
                Button(action: {
                    Task {
                        await vm.connect()
                    }
                }) {
                    if vm.isLoading {
                        HStack {
                            Text("Connecting...")
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        Text("Connect")
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .disabled(!vm.isValid || vm.isLoading)
            }
        }
        .navigationTitle("Add Server")
    }
}
