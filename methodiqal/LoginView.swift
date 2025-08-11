//
//  LoginView.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/9/25.
//

/* Module used under license. Copyright (c) 2024 Jayen Agrawal. */

import SwiftUI
import UIKit

struct LoginView: View {
    @ObservedObject var loginController: LoginController
    @Environment(\.colorScheme) var colorScheme
    var lightLoginSplash: (String, Color, Color) = [("LightLoginSplash0", Color.white, Color.black), ("LightLoginSplash1", Color.black, Color.white), ("LightLoginSplash2", Color.black, Color.white), ("LightLoginSplash3", Color.black, Color.white)].randomElement()!
    var darkLoginSplash: (String, Color, Color) = [("DarkLoginSplash0", Color.white, Color.white), ("DarkLoginSplash1", Color.white, Color.white), ("DarkLoginSplash2", Color.white, Color.white), ("DarkLoginSplash3", Color.white, Color.white)].randomElement()!
    @State private var imageTextColor: Color = Color.black
    @State private var bottomImageText: Color = Color.white
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                
                // All current images used under license. Copyright (c) 2022, 2023, 2024, and 2025 Jayen Agrawal
                if colorScheme == .light {
                    Image(lightLoginSplash.0)
                        .resizable()
                        .edgesIgnoringSafeArea(.all)
                        .scaledToFill()
                        .blur(radius: 4)
                        .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                        .onAppear() {
                            self.imageTextColor = lightLoginSplash.1
                            self.bottomImageText = lightLoginSplash.2
                        }
                } else {
                    Image(darkLoginSplash.0)
                        .resizable()
                        .edgesIgnoringSafeArea(.all)
                        .scaledToFill()
                        .blur(radius: 4)
                        .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                        .onAppear() {
                            self.imageTextColor = darkLoginSplash.1
                            self.bottomImageText = darkLoginSplash.2
                        }
                }
                
                switch loginController.state {
                case 0: (
                    VStack {
                        HStack {
                            Text("methodiqal")
                                .font(.largeTitle)
                                .fontDesign(.rounded)
                                .foregroundStyle(imageTextColor)
                                .bold()
                                .padding(.top)
                            Spacer()
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 50)
                                .frame(width: 10, height: 10)
                            ProgressView()
                        }
                    }
                        .padding()
                        .onAppear() {
                            loginController.loadAuthStatus()
                        }
                )
                case 1, 2: (
                    VStack {
                        HStack {
                            Text("methodiqal")
                                .font(.largeTitle)
                                .fontDesign(.rounded)
                                .foregroundStyle(imageTextColor)
                                .bold()
                                .padding(.top)
                            Spacer()
                        }
                        Picker("Log In/Create Account", selection: $loginController.state) {
                            Text("Log In").tag(1)
                            Text("Create Account").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .foregroundStyle(imageTextColor)
                        Spacer()
                        if loginController.state == 1 {
                            LoginTextField(text: $loginController.authenticationData[0], placeholder: "Username")
                                .textContentType(.username)
                            LoginTextFieldSecure(text: $loginController.authenticationData[1], placeholder: "Password")
                                .textContentType(.password)
                            Button("Log In") {
                                loginController.authenticate()
                            }
                            .padding()
                            .font(.title3)
                            .buttonStyle(.borderedProminent)
                        } else if loginController.state == 2 {
                            LoginTextField(text: $loginController.authenticationData[0], placeholder: "Username")
                                .textContentType(.username)
                            LoginTextFieldSecure(text: $loginController.authenticationData[1], placeholder: "Password")
                                .textContentType(.password)
                            Button("Create") {
                                loginController.authenticate()
                            }
                            .padding()
                            .font(.title3)
                            .buttonStyle(.borderedProminent)
                        } else {
                            Text("Fatal error. LoginView (1, 2 case), state invalid (was \(loginController.state)");
                        }
                        Spacer()
                        Text("An account is required to access methodiqal services. By continuing, you agree to our [Terms of Use]() and [Privacy Policy]().")
                            .padding()
                            .font(.caption)
                            .foregroundStyle(bottomImageText)
                    }
                        .padding()
                )
                case 3: (
                    VStack {
                        Spacer(); ProgressView(); Text("Authenticating"); Spacer();
                    }
                )
                case 4: (
                    VStack {
                        Spacer(); ProgressView(); Text("Authentication Successful"); Spacer();
                    }
                        .onAppear() {
                            // close auth
                        }
                )
                default: (
                    VStack {
                        Spacer(); Text("Fatal error. LoginView (default case), state invalid (was \(loginController.state)"); Spacer()
                    }
                )
                }
            }
            .alert(
                isPresented: $loginController.showAlert,
                content: {
                    Alert(
                        title: Text("Error"),
                        message: Text(loginController.alertMessage),
                        dismissButton: .default(Text("Dismiss"))
                    )
                })
        }
    }
}

struct LoginTextField: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        TextField(placeholder, text: $text)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.black.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.1), lineWidth: 1))
            )
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .frame(maxWidth: .infinity)
            .environment(\.colorScheme, .dark)
    }
}

struct LoginTextFieldSecure: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        SecureField(placeholder, text: $text)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.black.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.1), lineWidth: 1))
            )
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .frame(maxWidth: .infinity)
            .environment(\.colorScheme, .dark)
    }
}

/* End module */

#Preview {
    LoginView(loginController: LoginController())
}

