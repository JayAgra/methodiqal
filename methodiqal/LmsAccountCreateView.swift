//
//  LmsAccountCreateView.swift
//  methodiqal
//
//  Created by Jayen Agrawal on 8/11/25.
//

import SwiftUI

struct LmsAccountCreateView: View {
    @State var lmsType: LmsType = .canvas
    
    var body: some View {
        VStack {
            Form {
                Picker("LMS", selection: $lmsType) {
                    Text("Canvas").tag(LmsType.canvas)
                }
                .pickerStyle(.menu)
                
            }
        }
        .navigationTitle("Add LMS Account")
    }
}

#Preview {
    LmsAccountCreateView()
}
