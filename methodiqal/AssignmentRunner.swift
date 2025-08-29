//
//  AssignmentRunner.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/9/25.
//

import Foundation

struct AssignmentRunner {
    func createJsonData(assignment: Assignment) -> Result<Data, Error> {
        do {
            return .success(try JSONSerialization.data(withJSONObject: ["prompt": assignment.toString()]))
        } catch {
            return .failure(error)
        }
    }
    
    func runAssignment(data: Data, completion: @escaping ([AssignmentEvent]) -> Void) {
        guard let gpt = URL(string: "https://methodiqal.io/api/v1/chatgpt") else {
            completion([])
            return
        }
        
        let token = getToken();
        
        var request = URLRequest(url: gpt)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        sharedSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completion([])
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion([])
                return
            }
            switch httpResponse.statusCode {
            case 200:
                if let data = data {
                    do {
                        let resp = try JSONDecoder().decode(GptResponse.self, from: data)
                        
                        if let content = resp.choices.first?.message.content,
                           let jsonData = content.data(using: .utf8) {
                            do {
                                let assignment = try JSONDecoder().decode([AssignmentEvent].self, from: jsonData)
                                completion(assignment)
                            } catch {
                                print("Failed to decode AssignmentEvent: \(error)")
                            }
                        }
                    } catch {
                        completion([])
                    }
                } else {
                    completion([])
                }
            default:
                completion([])
            }
        }.resume()
    }
}

public struct GptAssignmentResponse: Codable {
    
}

struct GptResponse: Decodable {
    let choices: [GptResponseChoice]
}

struct GptResponseChoice: Decodable {
    let message: GptResponseMessage
}

struct GptResponseMessage: Decodable {
    let content: String
}

public struct AssignmentEvent: Codable {
    let date: Date
    let title: String
    let description: String
    let duration: Duration
    
    enum CodingKeys: String, CodingKey {
        case date
        case title
        case description
        case duration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let dateString = try container.decode(String.self, forKey: .date)
        let isoFormatter = ISO8601DateFormatter()
        self.date = isoFormatter.date(from: dateString) ?? Date()

        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decode(String.self, forKey: .description)

        let durationString = try container.decode(Int.self, forKey: .duration)
        let minutes = durationString
        self.duration = Duration.seconds(60 * minutes)
    }
}
