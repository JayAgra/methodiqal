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
    
    func runAssignment(data: Data, completion: @escaping (String) -> Void) {
        guard let gpt = URL(string: "https://methodiqal.io/api/v1/chatgpt") else {
            completion("")
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
                completion(error.localizedDescription)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion("")
                return
            }
            switch httpResponse.statusCode {
            case 200:
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    completion(responseString)
                } else {
                    completion("")
                }
            default:
                completion("")
            }
        }.resume()
    }
}
