//
//  LoadingView.swift
//  imageAI
//
//  Created by Dmitriy Chervyakov on 07.01.2023.
//

import SwiftUI

struct LoadingView: View {
    @StateObject var appState: AppState

    var body: some View {
        switch appState.state {
        case .waitingToDownload, .undetermined:
            VStack {
                Text("Before starting, you need to download the AI ​​model to your device (size is about 2.3Gb)")
                    .multilineTextAlignment(.center)
                    .padding()
                Button {
                    Task {
                        await appState.prepare()
                    }
                } label: {
                    Text("Download AI model").font(.title2)
                }.buttonStyle(.borderedProminent)
            }
        case let .downloading(progress, downloaded, total):
            VStack {
                ProgressView(value: progress, total: 1) {
                    Text("Loading...")
                } currentValueLabel: {
                    HStack {
                        Text("\((progress * 100).formatted())%")
                        Spacer()
                        Text("\(downloaded.formatted(.byteCount(style: .decimal)))/\(total.formatted(.byteCount(style: .decimal)))")
                    }

                }.frame(maxWidth: 250)
            }.padding()

        case .uncompressing:
            Text("Uncompressing, do not close the App")
        case let .failed(error):
            ErrorPopover(errorMessage: "Could not load model, error: \(error)").transition(.move(edge: .top))
        default:
            Text("Final preparation")
        }

    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView(appState: AppState(model: .v21Base))
    }
}

struct ErrorPopover: View {
    var errorMessage: String

    var body: some View {
        Text(errorMessage)
            .font(.headline)
            .padding()
            .foregroundColor(.red)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}
