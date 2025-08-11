//
//  Course.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/11/25.
//

import Foundation

struct Course: Codable, Hashable {
    let id: String
    let name: String?
    let originalName: String?
    let timeZone: String?
}

