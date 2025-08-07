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
    let createdAt: Date
    let updatedAt: Date?
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

