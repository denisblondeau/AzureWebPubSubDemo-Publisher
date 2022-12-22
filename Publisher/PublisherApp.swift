//
//  PublisherApp.swift
//  Publisher
//
//  Created by Denis Blondeau on 2022-12-19.
//

import SwiftUI

@main
struct PublisherApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, maxWidth: 400, minHeight: 400, maxHeight: 400)
        }
        .windowResizability(.contentSize)
        
    }
}
