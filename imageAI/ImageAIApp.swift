//
//  imageAIApp.swift
//  imageAI
//
//  Created by Dmitriy Chervyakov on 06.01.2023.
//

import SwiftUI

@main
struct ImageAIApp: App {
    @StateObject var appState = AppState(model: .v21Base)

    var body: some Scene {
        WindowGroup {
            switch appState.state {
            case .readyOnDisk:
                ContentView(appState: appState).transition(.opacity)
            default:
                LoadingView(appState: appState).transition(.opacity)
            }
        }
    }
}

extension String: Error {}
