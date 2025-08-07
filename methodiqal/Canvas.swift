//
//  Canvas.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/7/25.
//

import Foundation

public struct CanvasAssignmentResponse: Codable {
    let id: Int
    let name: String
    let description: String?
    let created_at: String
    let updated_at: String?
    let due_at: String?
//    let lock_at: String?
//    let unlock_at: String?
    let course_id: Int
//    let html_url: String
    let points_possible: Double?
    let submission_types: [String]
//    let has_submitted_submissions: Bool
    let submission: String?
//    let rubric: String?
//    let is_quiz_assignment: Bool
    let workflow_state: String
}

extension CanvasAssignmentResponse {
    func toUniversal(courseName: String) -> Assignment {
        let formatter = ISO8601DateFormatter()
        
        func parseDate(_ dateString: String?) -> Date? {
            guard let dateString = dateString else { return nil }
            return formatter.date(from: dateString)
        }
        
        let status = AssignmentStatus(fromString: self.workflow_state)
        let submissionType = self.submission_types.first.flatMap { SubmissionType(fromString: $0) } ?? .none
        
        return Assignment(
            id: String(self.id),
            source: "Canvas",
            title: self.name,
            description: self.description,
            dueDate: parseDate(self.due_at),
            submissionType: submissionType,
            status: status,
            pointsPossible: Int(self.points_possible ?? 0.0),
            courseID: String(self.course_id),
            courseName: courseName,
            createdAt: parseDate(self.created_at) ?? Date(),
            updatedAt: parseDate(self.updated_at) ?? Date()
        )
    }
}

// provides flexibility to change storage method
func getCanvasToken() -> String? {
    // return UserDefaults.standard.string(forKey: "canvasToken")
    return ""
}

func getCanvasBaseUrl() -> URL? {
    // return URL(string: UserDefaults.standard.string(forKey: "canvasURL") ?? "https://canvas.instructure.com/api/v1")
    return URL(string: "")
}

struct CanvasClient {
    func getAllAssignments(courseID: String, completion: @escaping (Result<[Assignment], Error>) -> Void) {
        
        guard let token = getCanvasToken() else {
            completion(.failure(NSError(domain: "CanvasClientError", code: 0, userInfo: [NSLocalizedDescriptionKey: "the API token for Canvas was not provided"])))
            return
        }
        
        guard let baseURL = getCanvasBaseUrl() else {
            completion(.failure(NSError(domain: "CanvasClientError", code: 0, userInfo: [NSLocalizedDescriptionKey: "the base URL for Canvas was not provided"])))
            return
        }
        
        var allAssignments = [Assignment]()
        var nextURL: URL? = baseURL.appendingPathComponent("/courses/\(courseID)/assignments")
        
        fetchAssignmentsPage(url: nextURL, token: token) { result in
            switch result {
            case .success((let assignments, let nextPageURL)):
                allAssignments.append(contentsOf: assignments)
                
                if let nextPageURLCheck = nextPageURL {
                    nextURL = nextPageURLCheck
                    self.fetchAssignmentsPage(url: nextURL, token: token) { result in
                        switch result {
                        case .success((let newAssignments, _)):
                            allAssignments.append(contentsOf: newAssignments)
                            completion(.success(allAssignments))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                } else {
                    completion(.success(allAssignments))
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func fetchAssignmentsPage(url: URL?, token: String, completion: @escaping (Result<([Assignment], URL?), Error>) -> Void) {
        guard let url = url else {
            completion(.failure(NSError(domain: "CanvasClientError", code: 0, userInfo: [NSLocalizedDescriptionKey: "invalid URL"])))
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "CanvasClientError", code: 0, userInfo: [NSLocalizedDescriptionKey: "no data received"])))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                
                let assignments = try decoder.decode([CanvasAssignmentResponse].self, from: data)
                
                var nextPageURL: URL?
                if let linkHeader = (response as? HTTPURLResponse)?.allHeaderFields["Link"] as? String {
                    if let nextLink = extractNextPageURL(from: linkHeader) {
                        nextPageURL = nextLink
                    }
                }
                
                var universal: [Assignment] = []
                
                assignments.forEach { assignment in
                    universal.append(assignment.toUniversal(courseName: String(assignment.course_id)))
                }
                
                completion(.success((universal, nextPageURL)))
                
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    private func extractNextPageURL(from linkHeader: String) -> URL? {
        let regex = try? NSRegularExpression(pattern: "<(.*?)>; rel=\"next\"", options: [])
        let matches = regex?.matches(in: linkHeader, range: NSRange(linkHeader.startIndex..., in: linkHeader))
        
        guard let match = matches?.first else {
            return nil
        }
        
        let nextPageURLRange = match.range(at: 1)
        let nextPageURLString = (linkHeader as NSString).substring(with: nextPageURLRange)
        return URL(string: nextPageURLString)
    }
}

