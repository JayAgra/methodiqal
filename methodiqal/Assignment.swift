//
//  Assignment.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/7/25.
//

import Foundation

struct Assignment: Codable, Hashable {
    let id: String
    let source: String
    let title: String
    let description: String?
    let dueDate: Date?
    let submissionType: SubmissionType
    let status: AssignmentStatus
    let pointsPossible: Int?
    let courseID: String
    let courseName: String
    let createdAt: Date?
    let updatedAt: Date?
    let timeZone: String?
}

extension Assignment {
    func toString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let meta = "Course: " + self.courseName + "\nTitle: " + self.title + "\nDue Date: " + formatter.string(from: self.dueDate ?? Date()) + "\nAssigned: " + formatter.string(from: self.createdAt ?? self.updatedAt ?? Date()) + "\nTime Zone: " + (self.timeZone ?? "America/New_York") + "\nType: " + self.submissionType.toString();
        return String(meta + "\n\nDescription: " + (self.description ?? "<none given>"));
    }
}

enum SubmissionType: Codable {
    case textEntry, fileUpload, url, recording, none, other
    
    init(fromString string: String) {
        switch string.lowercased() {
            case "online_text_entry": self = .textEntry
            case "online_upload": self = .fileUpload
            case "online_url": self = .url
            case "media_recording": self = .recording
            case "none": self = .none
            default: self = .other
        }
    }
}

extension SubmissionType {
    func toString() -> String {
        switch self {
        case .textEntry: "online_text_entry"
        case .fileUpload:  "online_upload"
        case .url: "online_url"
        case .recording: "media_recording"
        case .none: "none"
        default: "other"
        }
    }
}

enum AssignmentStatus: Codable {
    case posted, submitted, graded, other
    
    init(fromString string: String) {
        switch string.lowercased() {
        case "posted": self = .posted
        case "submitted": self = .submitted
        case "graded": self = .graded
        default: self = .other
        }
    }
}

