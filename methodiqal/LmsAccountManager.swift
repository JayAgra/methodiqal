//
//  LmsAccountManager.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/11/25.
//

import SwiftUI

struct LmsAccountManager: View {
    let uuid: UUID
    @State var coursesClone: [Course]
    
    init(uuid: UUID) {
        self.uuid = uuid
        let accounts = LmsAccountStore.shared.accounts(for: .canvas).filter( { $0.id == uuid } ).first
        self.coursesClone = accounts?.courses ?? []
    }
    
    var body: some View {
        VStack {
            List {
                ForEach(coursesClone, id: \.id) { course in
                    VStack {
                        HStack {
                            Text(course.enabled ? "✅" : "❌")
                            Text((course.originalName ?? course.name) ?? course.id)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            var courses = coursesClone
                            let index = courses.firstIndex(where: { $0.id == course.id })
                            courses[index ?? 0].enabled.toggle()
                            self.coursesClone = LmsAccountStore.shared.updateCourses(for: uuid, courses: courses)
                        }
                    }
                }
                Button(action: {
                    CanvasClient().fetchCourses(account: LmsAccountStore.shared.getAccount(uuid)!) { courses_out in
                        switch courses_out {
                        case .success(let courses):
                            self.coursesClone = LmsAccountStore.shared.updateCourses(for: uuid, courses: courses)
                        case .failure:
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                        }
                    }
                }, label: {
                    Label("Refresh Courses", systemImage: "key").labelStyle(.titleOnly)
                })
            }
        }
        .onAppear {
            let accounts = LmsAccountStore.shared.accounts(for: .canvas).filter( { $0.id == uuid } ).first
            self.coursesClone = accounts?.courses ?? []
        }
    }
}

#Preview {
    LmsAccountManager(uuid: UUID())
}
