//
//  ServerEditView.swift
//  NavidromeClient3
//
//  Swift 6: Fixed property name (host -> serverUrl)
//

import SwiftUI

struct ServerEditView: View {
    @Binding var viewModel: ConnectionViewModel
    
    var body: some View {
        Form {
            Section(header: Text("Server Details")) {
                // FIX: Changed .host to .serverUrl
                TextField("Server URL (e.g. https://music.example.com)", text: $viewModel.serverUrl)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                TextField("Username", text: $viewModel.username)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
            }
            
            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            Section {
                Button(action: {
                    Task {
                        await viewModel.connect()
                    }
                }) {
                    if viewModel.isLoading {
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
                .disabled(!viewModel.isValid || viewModel.isLoading)
            }
        }
        .navigationTitle("Add Server")
    }
}
