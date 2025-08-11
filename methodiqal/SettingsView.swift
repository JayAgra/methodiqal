//
//  SettingsView.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/11/25.
//

import SwiftUI

struct SettingsView: View {
    @State var selectedAccount: UUID? = nil
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    List {
                        ForEach(LmsAccountStore.shared.allAccounts(), id: \.id) { account in
                            NavigationLink(destination: {
                                LmsAccountManager(uuid: account.id)
                            }, label: {
                                VStack {
                                    Text(account.nickname)
                                        .font(.headline)
                                    Text(account.baseUrl)
                                    Text(account.enabled ? "Enabled" : "Disabled")
                                        .font(.footnote)
                                }
                            })
                        }
                        NavigationLink(destination: {
                            LmsAccountCreateView()
                        }, label: {
                            Label("Add LMS Account", systemImage: "key")
                                .labelStyle(.titleOnly)
                        })
                    }
                }
                Section {
                    Button(action: {
                        updateAuthToken(tokenData: Data())
                    }, label: {
                        Label("Log Out", systemImage: "key").labelStyle(.titleOnly)
                    })
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
