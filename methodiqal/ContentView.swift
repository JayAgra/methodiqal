//
//  ContentView.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 7/25/25.
//

import SwiftUI

struct ContentView: View {
    @State private var assignments: [Assignment] = []
    
    var body: some View {
        NavigationStack {
            Button(action: {
                LmsAccountStore.shared.accountsEnabled(for: .canvas).forEach({ account in
                    account.courses.forEach({ course in
                        if course.enabled {
                            CanvasClient().getAllAssignments(account: account, course: course) { assignment in
                                switch assignment {
                                case .success(let success):
                                    assignments += success
                                case .failure(let failure):
                                    print(failure)
                                }
                            }
                        }
                    })
                })
            }, label: {
                Label("Hi", systemImage: "globe")
            })
            NavigationLink(destination: SettingsView(), label: { Label("Settings", systemImage: "key").labelStyle(.titleOnly) })
            if !assignments.isEmpty {
                List {
                    ForEach(assignments, id: \.self) { assignment in
                        var formattedDueDate: String {
                            let formatter = DateFormatter()
                            formatter.dateStyle = .medium
                            formatter.timeStyle = .short
                            return formatter.string(from: assignment.dueDate ?? Date())
                        }
                        NavigationLink(destination: {
                            AssignmentView(assignment: assignment)
                        }, label:{
                            VStack(alignment: .leading) {
                                Text(String(assignment.title))
                                    .font(.title2)
                                Text(assignment.courseName)
                                Text(formattedDueDate)
                                    .font(.footnote)
                            }
                        })
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

