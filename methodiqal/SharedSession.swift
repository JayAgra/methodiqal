//
//  SharedSession.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/9/25.
//

import Foundation

let sharedSession: URLSession = {
    let configuration = URLSessionConfiguration.default
    configuration.httpCookieStorage = HTTPCookieStorage.shared
    
    return URLSession(configuration: configuration)
}()
