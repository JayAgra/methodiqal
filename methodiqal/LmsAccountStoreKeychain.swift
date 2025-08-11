//
//  LmsAccountStoreKeychain.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/11/25.
//

import Foundation
import Security

final class LmsAccountStoreKeychain {
    static let shared = LmsAccountStoreKeychain()
    
    private init() {}
    
    func save(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func read(for key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var dataTypeReference: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &dataTypeReference) == noErr,
           let data = dataTypeReference as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }
        return nil
    }
    
    func delete(for key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
