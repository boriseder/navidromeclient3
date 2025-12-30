//
//  KeyChainHelper.swift
//  NavidromeClient3
//
//  Swift 6: Secure Credentials Storage
//

import Foundation
import Security

final class KeyChainHelper: @unchecked Sendable {
    static let shared = KeyChainHelper()
    
    private let service = "com.navidrome.client"
    private let account = "navidrome_user_credentials"
    
    private init() {}
    
    // MARK: - Public API
    
    func saveCredentials(_ credentials: ServerCredentials) {
        do {
            let data = try JSONEncoder().encode(credentials)
            save(data, service: service, account: account)
            AppLogger.general.info("Credentials saved securely.")
        } catch {
            AppLogger.general.error("Failed to encode credentials: \(error)")
        }
    }
    
    func retrieveCredentials() -> ServerCredentials? {
        guard let data = read(service: service, account: account) else { return nil }
        do {
            let credentials = try JSONDecoder().decode(ServerCredentials.self, from: data)
            return credentials
        } catch {
            AppLogger.general.error("Failed to decode credentials: \(error)")
            return nil
        }
    }
    
    func deleteCredentials() {
        delete(service: service, account: account)
        AppLogger.general.info("Credentials deleted.")
    }
    
    // MARK: - Keychain Operations
    
    private func save(_ data: Data, service: String, account: String) {
        let query = [
            kSecValueData: data,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as [String: Any]
        
        // Delete existing item first to ensure update
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            AppLogger.general.error("Keychain save error: \(status)")
        }
    }
    
    private func read(service: String, account: String) -> Data? {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true
        ] as [String: Any]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }
    
    private func delete(service: String, account: String) {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword
        ] as [String: Any]
        
        SecItemDelete(query as CFDictionary)
    }
}
