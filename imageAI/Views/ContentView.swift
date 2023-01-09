//
//  ContentView.swift
//  imageAI
//
//  Created by Yasuhito Nagatomo on 2022/12/05.
//

import SwiftUI

struct ContentView: View {
    @StateObject var appState: AppState
    @StateObject var imageGenerator = ImageGenerator()

    @State private var generationParameter =
        ImageGenerator.GenerationParameter(
            prompt: "cyberpunk night street with modern cars",
            negativePrompt: "",
            stepCount: 20,
            imageCount: 1,
            disableSafety: true,
            isShowSteps: false,
            isUpscale: false
        )
    var body: some View {
        ScrollView {
            VStack {
                Text("Stable Diffusion v2.1").font(.title).padding()

                PromptView(parameter: $generationParameter)
                    .disabled(imageGenerator.generationState != .idle)

                if imageGenerator.generationState == .idle {
                    Button(action: generate) {
                        Text("Generate").font(.title)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        ProgressView()

                        switch imageGenerator.generationState {
                        case .preparation:
                            Text("Preparation step (about 1 min)")
                                .font(.callout)
                        case let .generating(progressStep: step, countStep: count, image: image):

                            Text("Progress \(step) out of \(count)")
                                .font(.callout)

                            if let imageUnwrapped = image {
                                Image(imageUnwrapped, scale: 1.0, label: Text(""))
                                    .resizable()
                                    .scaledToFit()
                            }

                        case let .upscaling(image: image):
                            Text("Upscaling")
                                .font(.callout)

                            Image(image, scale: 1.0, label: Text(""))
                                .resizable()
                                .scaledToFit()
                            
                        case .idle:
                            Text("Wating for pipeline start")
                        }

                    }

                }

                if let generatedImages = imageGenerator.generatedImages {
                    ForEach(generatedImages.images) {
                        Image(uiImage: $0.uiImage)
                            .resizable()
                            .frame(maxWidth: 1024, maxHeight: 1024)
                            .scaledToFit()
                    }
                }
            }
        }
        .padding()
    }

    func generate() {
        imageGenerator.generateImages(generationParameter, modelUrl: appState.compiledPath.url)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(appState: AppState(model: .v21Base))
    }
}

struct PromptView: View {
    @Binding var parameter: ImageGenerator.GenerationParameter

    var body: some View {
        VStack(spacing: 16) {
            HStack { Text("Prompt:"); Spacer() }
            TextField("Provide prompt for generated image", text: $parameter.prompt)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            HStack { Text("Negative Prompt:"); Spacer() }
            TextField("Provide negative prompt for generated image", text: $parameter.negativePrompt)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Stepper(value: $parameter.imageCount, in: 1...10) {
                Text("Image Count: \(parameter.imageCount)")
            }
            Stepper(value: $parameter.stepCount, in: 1...100) {
                Text("Iteration steps: \(parameter.stepCount)")
            }
            Toggle("Upscale final result to 2048x2048", isOn: $parameter.isUpscale)
            Toggle("Show intermediate results (it takes twice as long for the final result)", isOn: $parameter.isShowSteps)
        }
        .padding()
    }
}
