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
    func toUniversal(course: Course) -> Assignment {
        let formatter = ISO8601DateFormatter()
        
        func parseDate(_ dateString: String?) -> Date? {
            guard let dateString = dateString else { return nil }
            return formatter.date(from: dateString)
        }
        
        let status = AssignmentStatus(fromString: self.workflow_state)
        let submissionType = self.submission_types.first.flatMap { SubmissionType(fromString: $0) } ?? .none
        
        return Assignment(
            source: .canvas,
            sourceBaseUrl: course.baseUrl,
            title: self.name,
            description: self.description,
            dueDate: parseDate(self.due_at),
            submissionType: submissionType,
            status: status,
            pointsPossible: Int(self.points_possible ?? 0.0),
            courseId: String(self.course_id),
            courseName: course.originalName ?? course.name ?? course.id,
            createdAt: parseDate(self.created_at) ?? Date(),
            updatedAt: parseDate(self.updated_at) ?? Date(),
            timeZone: course.timeZone ?? "America/New_York"
        )
    }
}

public struct CanvasCourseResponse: Codable {
    let id: Int
    let name: String?
    let course_code: String?
    let original_name: String?
    let workflow_state: String?
    let end_at: String?
    let time_zone: String?
}

extension CanvasCourseResponse {
    func toUniversal(baseUrl: String) -> Course {
        return Course(
            id: String(self.id),
            baseUrl: baseUrl,
            lms: .canvas,
            name: self.original_name ?? self.name ?? String(self.id),
            originalName: self.original_name,
            timeZone: self.time_zone ?? "America/New_York",
            enabled: true
        )
    }
}

struct CanvasClient {
    func validateToken(baseURL: String, token: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/self") else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil, let httpResponse = response as? HTTPURLResponse else {
                completion(false)
                return
            }
            if httpResponse.statusCode == 200 {
                completion(true)
            } else {
                completion(false)
            }
        }
        task.resume()
    }
    
    func fetchCourses(account: LmsAccount, completion: @escaping (Result<[Course], Error>) -> Void) {
        guard let token = LmsAccountStoreKeychain.shared.read(for: account.tokenKeychainId), let baseURL = URL(string: account.baseUrl) else {
            completion(.failure(NSError(domain: "CanvasAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Token or base URL is missing."])))
            return
        }
        
        let url = baseURL.appendingPathComponent("/courses")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let sharedSession = URLSession.shared
        
        sharedSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error)); return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "CanvasAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data received."]))); return
            }
            
            do {
                let courses = try JSONDecoder().decode([CanvasCourseResponse].self, from: data)
                var universal: [Course] = []
                courses.forEach { course in
                    universal.append(course.toUniversal(baseUrl: baseURL.host() ?? "canvas.instructure.com"))
                }
                completion(.success((universal)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func getAllAssignments(account: LmsAccount, course: Course, completion: @escaping (Result<[Assignment], Error>) -> Void) {
        guard let token = LmsAccountStoreKeychain.shared.read(for: account.tokenKeychainId), let baseURL = URL(string: account.baseUrl) else {
            completion(.failure(NSError(domain: "CanvasAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Token or base URL is missing."])))
            return
        }
        
        var allAssignments = [Assignment]()
        var nextURL: URL? = baseURL.appendingPathComponent("/courses/\(course.id)/assignments")
        print("A")
        fetchAssignmentsPage(url: nextURL, token: token, course: course) { result in
            print("B")
            switch result {
            case .success((let assignments, let nextPageURL)):
                print("C")
                allAssignments.append(contentsOf: assignments)
                
                if let nextPageURLCheck = nextPageURL {
                    nextURL = nextPageURLCheck
                    self.fetchAssignmentsPage(url: nextURL, token: token, course: course) { result in
                        switch result {
                        case .success((let newAssignments, _)):
                            allAssignments.append(contentsOf: newAssignments)
                            completion(.success(Array(Set(allAssignments))))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                } else {
                    completion(.success(Array(Set(allAssignments))))
                }
                
            case .failure(let error):
                print("D")
                completion(.failure(error))
            }
        }
    }
    
    private func fetchAssignmentsPage(url: URL?, token: String, course: Course, completion: @escaping (Result<([Assignment], URL?), Error>) -> Void) {
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
                    universal.append(assignment.toUniversal(course: course))
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

