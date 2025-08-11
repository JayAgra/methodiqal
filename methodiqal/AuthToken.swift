//
//  AuthToken.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/11/25.
//

import Foundation
import Security

func saveToken(token: String) {
    let tokenData = token.data(using: .utf8)!
    
    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: "authToken",
        kSecValueData: tokenData,
        kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
    ]
    
    let status = SecItemAdd(query as CFDictionary, nil)
    
    if status == errSecSuccess {
        print("token saved")
    } else if status == errSecDuplicateItem {
        print("duplicate item, updating")
        updateAuthToken(tokenData: tokenData)
    } else {
        print("save failure \(status)")
    }
}

func updateAuthToken(tokenData: Data) {
    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: "authToken"
    ]
    
    let attributesToUpdate: [CFString: Any] = [
        kSecValueData: tokenData
    ]
    
    let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
    
    if status == errSecSuccess {
        print("token updated successfully")
    } else {
        print("failed to update– \(status)")
    }
}

func getToken() -> String {
    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: "authToken",
        kSecReturnData: true,
        kSecMatchLimit: kSecMatchLimitOne
    ]
    
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    
    if status == errSecSuccess, let data = result as? Data,
    let token = String(data: data, encoding: .utf8) {
        return token
    }
    
    print("Failed to retrieve token: \(status)")
    return ""
}
