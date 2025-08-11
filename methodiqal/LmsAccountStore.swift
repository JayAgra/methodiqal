//
//  LmsAccountStore.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/11/25.
//

import Foundation

enum LmsType: String, Codable, CaseIterable {
    case canvas = "Canvas"
    // case brightspace = "Brightspace"
    // case googleClassroom = "Google Classroom"
    
    var id: String { rawValue }
}

struct LmsAccount: Identifiable, Codable {
    let id: UUID
    let lmsType: LmsType
    var baseUrl: String
    var nickname: String
    var enabled: Bool
    var courses: [Course]
    var tokenKeychainId: String
}

final class LmsAccountStore {
    static let shared = LmsAccountStore()
    private let fileName = "account_data.json"
    private var accounts: [LmsAccount] = []
    
    private init() { load() }
    
    func allAccounts() -> [LmsAccount] {
        return accounts
    }
    
    func allEnabledAccounts() -> [LmsAccount] {
        return accounts.filter { $0.enabled }
    }
    
    func accounts(for type: LmsType) -> [LmsAccount] {
        return accounts.filter { $0.lmsType == type }
    }
    
    func accountsEnabled(for type: LmsType) -> [LmsAccount] {
        return accounts(for: type).filter { $0.enabled }
    }
    
    func addAccount(_ account: LmsAccount, token: String) {
        accounts.append(account)
        LmsAccountStoreKeychain.shared.save(token, for: account.tokenKeychainId)
        save()
    }
    
    func removeAccount(_ id: UUID) {
        if let account = accounts.first(where: { $0.id == id }) {
            LmsAccountStoreKeychain.shared.delete(for: account.tokenKeychainId)
        }
        accounts.removeAll { $0.id == id }
        save()
    }
    
    func toggleAccount(for accountId: UUID) -> Bool {
        guard let index = accounts.firstIndex(where: { $0.id == accountId }) else { return false }
        accounts[index].enabled.toggle()
        save()
        return accounts[index].enabled
    }
    
    func updateCourses(for accountId: UUID, courses: [Course]) -> [Course] {
        guard let index = accounts.firstIndex(where: { $0.id == accountId }) else { return [] }
        accounts[index].courses = courses
        save()
        return accounts[index].courses
    }
    
    func updateNickname(for accountId: UUID, newName: String) -> String {
        guard let index = accounts.firstIndex(where: { $0.id == accountId }) else { return "Update Failed" }
        accounts[index].nickname = newName
        save()
        return accounts[index].nickname
    }
    
    func updateToken(for accountId: UUID, newToken: String) {
        guard let account = accounts.first(where: { $0.id == accountId }) else { return }
        LmsAccountStoreKeychain.shared.save(newToken, for: account.tokenKeychainId)
    }
    
    private func save() {
        let url = getFileUrl()
        if let data = try? JSONEncoder().encode(accounts) {
            try? data.write(to: url)
        }
    }
    
    private func load() {
        let url = getFileUrl()
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([LmsAccount].self, from: data) {
            accounts = decoded
        }
    }
    
    private func getFileUrl() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }
}
