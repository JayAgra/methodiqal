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
            CanvasClient().getAllAssignments(courseID: "58893") { result in
                print(1)
                switch result {
                case .success(let assignmentResult):
                    assignments += assignmentResult
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
                    VStack {
                        Text(String(assignment.title))
                            .font(.title3)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

