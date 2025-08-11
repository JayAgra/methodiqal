//
//  LmsAccountCreateView.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/11/25.
//

import SwiftUI

struct LmsAccountCreateView: View {
    @State var lmsType: LmsType = .canvas
    @State var accountName: String = ""
    @State var baseUrl: String = ""
    // the following variables will be replaced when oauth
    @State var token: String = ""
    @State var keyWorks: Bool = false
    
    var body: some View {
        VStack {
            Form {
                Section {
                    Picker("LMS", selection: $lmsType) {
                        Text("Canvas").tag(LmsType.canvas)
                    }
                    .pickerStyle(.menu)
                }
                Section {
                    TextField("Account Name", text: $accountName)
                }
                Section {
                    Text("i.e., https://canvas.instructure.com/api/v1")
                    TextField("Base URL", text: $baseUrl)
                }
                Section {
                    TextField("Token", text: $token)
                }
                Section {
                    Button(action: {
                        CanvasClient().validateToken(baseURL: baseUrl, token: token) { result in
                            if result {
                                keyWorks = true
                            } else {
                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                            }
                        }
                    }, label: {
                        Label("Test", systemImage: "key").labelStyle(.titleOnly)
                    })
                    Button(action: {
                        let newAccount = UUID();
                        LmsAccountStore.shared.addAccount(LmsAccount(id: newAccount, lmsType: .canvas, baseUrl: baseUrl, nickname: accountName, enabled: true, courses: [], tokenKeychainId: UUID().uuidString), token: token)
                        CanvasClient().fetchCourses(account: LmsAccountStore.shared.getAccount(newAccount)!) { courses_out in
                            switch courses_out {
                            case .success(let courses):
                                _ = LmsAccountStore.shared.updateCourses(for: newAccount, courses: courses)
                            case .failure:
                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                            }
                        }
                    }, label: {
                        Label("Add", systemImage: "key").labelStyle(.titleOnly)
                    })
                    .disabled(!keyWorks)
                }
            }
        }
        .navigationTitle("Add LMS Account")
    }
}

#Preview {
    LmsAccountCreateView()
}
