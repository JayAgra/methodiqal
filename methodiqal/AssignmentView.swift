//
//  AssignmentView.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/11/25.
//

import SwiftUI

struct AssignmentView: View {
    var assignment: Assignment
    var assignmentDue: String = ""
    @State var response = ""
    
    init(assignment: Assignment) {
        self.assignment = assignment
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        self.assignmentDue = formatter.string(from: assignment.dueDate ?? Date.now.addingTimeInterval(86400))
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(assignment.title)
                .font(.title)
            Text(assignment.courseName)
                .font(.subheadline)
            Text(assignmentDue)

            if response == "" {
                ProgressView()
            } else {
                ScrollView {
                    Text(response)
                }
                .padding()
            }
        }
        .padding()
        .onAppear() {
            switch AssignmentRunner().createJsonData(assignment: assignment) {
            case .success(let success):
                AssignmentRunner().runAssignment(data: success) { result in
                    response = result
                }
            case .failure:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}

#Preview {
    AssignmentView(assignment: Assignment(source: .canvas, sourceBaseUrl: "https://canvas.instructure.com/api/v1", title: "Champa Rice Essay", description: "Write a twelve page essay on champa rice. This is your final and 30% of your semester grade.", dueDate: Date.now.addingTimeInterval(259200), submissionType: .fileUpload, status: .posted, pointsPossible: 100, courseId: "18233", courseName: "AP World History", createdAt: Date.now.addingTimeInterval(-2592000), updatedAt: Date.now.addingTimeInterval(-2592000), timeZone: "America/New_York"))
}
