//
//  AssignmentStore.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/11/25.
//

import Foundation

final class AssignmentStore {
    static let shared = AssignmentStore()
    private let fileName = "assignments.json"
    private var assignments: Set<Assignment> = []
    
    private init() { load() }
    
    func addAssignments(_ newAssignments: [Assignment]) {
        let beforeCount = assignments.count
        assignments.formUnion(newAssignments)
        if assignments.count != beforeCount {
            save()
        }
    }
    
    func allAssignments() -> [Assignment] {
        return Array(assignments)
    }
    
    func assignmentsSortedByDueDate() -> [Assignment] {
        return assignments.sorted {
            guard let date1 = $0.dueDate, let date2 = $1.dueDate else {
                return $0.dueDate != nil
            }
            return date1 < date2
        }
    }
    
    func assignmentsDue(after date: Date) -> [Assignment] {
        return assignments.filter {
            if let due = $0.dueDate {
                return due > date
            }
            return false
        }.sorted { $0.dueDate! < $1.dueDate! }
    }
    
    func deleteAssignmentsDue(before date: Date) {
        let beforeCount = assignments.count
        assignments = assignments.filter {
            if let due = $0.dueDate {
                return due >= date
            }
            return true
        }
        if assignments.count != beforeCount {
            save()
        }
    }
    
    func deleteAssignments(courseId: String, baseURL: String) {
        let beforeCount = assignments.count
        assignments = assignments.filter {
            !($0.courseId == courseId && $0.sourceBaseUrl == baseURL)
        }
        if assignments.count != beforeCount {
            save()
        }
    }
    
    private func save() {
        let url = getFileURL()
        if let data = try? JSONEncoder().encode(Array(assignments)) {
            try? data.write(to: url)
        }
    }
    
    private func load() {
        let url = getFileURL()
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Assignment].self, from: data) {
            assignments = Set(decoded)
        }
    }
    
    private func getFileURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }
}
