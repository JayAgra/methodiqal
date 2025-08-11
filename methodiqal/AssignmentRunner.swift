//
//  AssignmentRunner.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/9/25.
//

import Foundation

struct AssignmentRunner {
    let url = URL(string: "https://methodiqal.io/api/v1/chatgpt");
    
    private func createJsonData(assignment: Assignment) -> Result<Data, Error> {
        do {
            return .success(try JSONSerialization.data(withJSONObject: ["prompt", assignment.toString()]))
        } catch {
            return .failure(error)
        }
    }
}
