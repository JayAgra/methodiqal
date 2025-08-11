//
//  Assignment.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/7/25.
//

import Foundation
import CryptoKit

struct Assignment: Codable {
    let id: String
    let source: LmsType
    let sourceBaseUrl: String
    let title: String
    let description: String?
    let dueDate: Date?
    let submissionType: SubmissionType
    let status: AssignmentStatus
    let pointsPossible: Int?
    let courseId: String
    let courseName: String
    let createdAt: Date?
    let updatedAt: Date?
    let timeZone: String?
    var breakdown: String?
    
    init(source: LmsType, sourceBaseUrl: String, title: String, description: String?, dueDate: Date?, submissionType: SubmissionType, status: AssignmentStatus, pointsPossible: Int?, courseId: String, courseName: String, createdAt: Date?, updatedAt: Date?, timeZone: String?, breakdown: String? = nil) {
        self.source = source
        self.sourceBaseUrl = sourceBaseUrl
        self.title = title
        self.description = description
        self.dueDate = dueDate
        self.submissionType = submissionType
        self.status = status
        self.pointsPossible = pointsPossible
        self.courseId = courseId
        self.courseName = courseName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.timeZone = timeZone
        self.breakdown = breakdown
        
        self.id = Assignment.makeHashId(
            source: source,
            baseUrl: sourceBaseUrl,
            courseId: courseId,
            title: title
        )
    }
    
    static func makeHashId(source: LmsType, baseUrl: String, courseId: String, title: String) -> String {
        let combined = "\(source.rawValue)|\(baseUrl)|\(courseId)|\(title)"
        let hash = SHA256.hash(data: Data(combined.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension Assignment: Equatable, Hashable {
    func toString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let meta = "Course: " + self.courseName + "\nTitle: " + self.title + "\nDue Date: " + formatter.string(from: self.dueDate ?? Date()) + "\nAssigned: " + formatter.string(from: self.createdAt ?? self.updatedAt ?? Date()) + "\nTime Zone: " + (self.timeZone ?? "America/New_York") + "\nType: " + self.submissionType.toString();
        return String(meta + "\n\nDescription: " + (self.description ?? "<none given>"));
    }
    
    static func == (lhs: Assignment, rhs: Assignment) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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

