//
//  LoginController.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/9/25.
//

import Foundation

struct TokenResponse: Codable {
    let token: String
}

class LoginController: ObservableObject {
    @Published public var showAlert: Bool = false
    @Published public var alertMessage: String = ""
    @Published public var state: Int = 0 // 1 = init, 1/2 = log in/create account, 3 = loading/action, 4 = welcome
    @Published public var authenticationData: [String] = ["", ""]
    
    func loadAuthStatus() {
        let token = getToken();
        if token == "" {
            state = 1; return
        } else {
            guard let whoami = URL(string: "https://methodiqal.io/api/v1/auth/whoami") else {
                state = 1; return
            }
            var request = URLRequest(url: whoami)
            request.httpMethod = "GET"
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            sharedSession.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    let statusCode = httpResponse.statusCode
                    switch statusCode {
                    case 200:
                        self.state = 4; return;
                    default:
                        self.state = 1; return;
                    }
                }
            }.resume()
        }
    }
    
    func authenticate() {
        let previousState = state
        state = 3
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: ["username": authenticationData[0], "password": authenticationData[1]])
            if previousState == 1 {
                loginHandle(jsonData: jsonData)
            } else {
                createHandle(jsonData: jsonData)
            }
        } catch {
            returnError(returnTo: previousState, message: "Failed to serialize the authentication data. \(error)")
        }
    }
    
    func loginHandle(jsonData: Data) {
        guard let login = URL(string: "https://methodiqal.io/api/v1/auth/login") else {
            returnError(returnTo: 1, message: "Client error: Failed to build request (Step: Login URL construct)")
            return;
        }
        var request = URLRequest(url: login)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        sharedSession.dataTask(with: request) { data, response, error in
            if let error = error {
                self.returnError(returnTo: 1, message: "Unknown Error: \(error.localizedDescription)")
                return;
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    if let data = data {
                        let decoder = JSONDecoder()
                        do {
                            let response = try decoder.decode(TokenResponse.self, from: data)
                            saveToken(token: response.token)
                            self.state = 4
                            return
                        } catch {
                            self.returnError(returnTo: 1, message: "Failed to parse token response from server")
                            return
                        }
                    }
                    self.returnError(returnTo: 1, message: "Server sent 200 OK but provided no content")
                    return
                case 400:
                    if let data = data {
                        let decoder = JSONDecoder()
                        do {
                            let response = try decoder.decode(TokenResponse.self, from: data)
                            switch response.token {
                            case "bad_s1", "bad_s3", "bad_s4":
                                self.returnError(returnTo: 1, message: "Username or password was incorrect")
                            case "bad_s2":
                                self.returnError(returnTo: 1, message: "Server encountered an error attempting to log you in")
                            default:
                                self.returnError(returnTo: 1, message: "Server provided an unknown reason for rejecting log in")
                            }
                            return
                        } catch {
                            self.returnError(returnTo: 1, message: "Failed to parse token response from server")
                            return
                        }
                    }
                    self.returnError(returnTo: 1, message: "Server rejected log in but provided no reasoning")
                    return
                default:
                    self.returnError(returnTo: 1, message: "Invalid or null server response")
                    return
                }
            }
        }.resume()
    }
    
    func createHandle(jsonData: Data) {
        guard let create = URL(string: "https://methodiqal.io/api/v1/auth/create") else {
            returnError(returnTo: 2, message: "Client error: Failed to build request (Step: Create URL construct)")
            return;
        }
        
        var request = URLRequest(url: create)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        sharedSession.dataTask(with: request) { data, response, error in
            if let error = error {
                self.returnError(returnTo: 1, message: "Unknown Error: \(error.localizedDescription)")
                return;
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    if let data = data {
                        let decoder = JSONDecoder()
                        do {
                            let response = try decoder.decode(TokenResponse.self, from: data)
                            saveToken(token: response.token)
                            self.state = 4
                            return
                        } catch {
                            self.returnError(returnTo: 1, message: "Failed to parse token response from server. Your account should exist.")
                            return
                        }
                    }
                    self.returnError(returnTo: 2, message: "Server sent 200 OK but provided no content")
                    return
                case 400:
                    self.returnError(returnTo: 2, message: "Your account was rejected for using forbidden characters. Please use only the following: a-z 0-9 A-Z - ~ ! @ # $ % ^ & * ( ) = + / \\ _ [ _ ] { } | ? . ,")
                    return
                case 409:
                    self.returnError(returnTo: 2, message: "The username you provided is already taken.")
                    return
                case 413:
                    self.returnError(returnTo: 2, message: "Your username and/or password was not between 3 and 64 characters (8 min for password)")
                    return
                case 500:
                    self.returnError(returnTo: 2, message: "The server encountered an error when trying to create your account")
                default:
                    self.returnError(returnTo: 2, message: "Invalid or null server response")
                    return
                }
            }
        }.resume()
    }
    
    func returnError(returnTo: Int, message: String) {
        DispatchQueue.main.async {
            self.alertMessage = message;
            self.state = returnTo;
            self.showAlert = true;
        }
    }
}
