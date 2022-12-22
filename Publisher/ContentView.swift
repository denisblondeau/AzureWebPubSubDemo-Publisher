//
//  ContentView.swift
//  Publisher
//
//  Created by Denis Blondeau on 2022-12-19.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject private var model = PubModel()
    @State private var message = ""
    
    var body: some View {
        VStack {
            HStack {
                TextField("Enter message to send...", text: $message)
                    .onSubmit(submitMessage)
                Button("Send", action: submitMessage)
                    .disabled(message.isEmpty)
                
            }
            .disabled(!model.isOpen)
            .padding()
            
            Text("Messages received")
            ScrollView {
                LazyVStack(alignment: .leading) {
                    Text(model.messageReceived)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(5)
            }
            .frame(width: 350, height: 175)
            .border(.green)
            .padding(.bottom)
            
            ScrollView {
                LazyVStack(alignment: .leading) {
                    Text(model.activityInformation)
                        .foregroundColor(.accentColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(5)
            }
            .frame(width: 350, height: 75)
            .border(.gray)
            
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding()
    }
    
    private func submitMessage() {
        model.sendMessage(message)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
