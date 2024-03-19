//
//  ContentView.swift
//  PDF-AutoRenamer
//
//  Created by mac on 2024/3/20.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var processor = PDFProcessor()
    
    var body: some View {
        VStack {
            Text(processor.message)
                .padding()
            
            Button(action: {
                processor.selectAndProcessPDF()
            }) {
                Text("Select and Rename PDF")
            }
            .padding()
        }
        .frame(width: 400, height: 300)
    }
}




#Preview {
    ContentView()
}
