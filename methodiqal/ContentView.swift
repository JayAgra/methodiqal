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
        Button(action: {
            print(0)
            CanvasClient().getAllAssignments(courseID: "52870") { result in
                print(1)
                switch result {
                case .success(let assignmentResult):
                    assignments += assignmentResult
                case .failure(let error):
                    print(error)
                }
            }
            CanvasClient().fetchCourses() { result in
                print(2)
                switch result {
                case .success(let coursesResult):
                    print(coursesResult)
                case .failure(let error):
                    print(error)
                }
            }
        }, label: {
            Label("Hi", systemImage: "globe")
        })
        
        if !assignments.isEmpty {
            List {
                ForEach(assignments, id: \.self) { assignment in
                    var formattedDueDate: String {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .short
                        return formatter.string(from: assignment.dueDate ?? Date())
                    }
                    
                    VStack {
                        Text(String(assignment.title))
                            .font(.title2)
                        Text(String(assignment.description ?? ""))
                        Text(formattedDueDate)
                            .font(.footnote)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

