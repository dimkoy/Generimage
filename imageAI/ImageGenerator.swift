//
//  ImageGenerator.swift
//  imageAI
//
//  Created by Dmitriy Chervyakov on 06.01.2023.
//

import UIKit
import StableDiffusion
import CoreML

@MainActor
final class ImageGenerator: ObservableObject {

    @Published var generationState: GenerationState = .idle
    @Published var generatedImages: GeneratedImages?
    @Published var isPipelineCreated = false

    private var currentGenerationParameters: GenerationParameter?
    private var sdPipeline: StableDiffusionPipeline?

    private lazy var upscaler: Upscaler = Upscaler()

    init() {
    }

    func setState(_ state: GenerationState) { // for actor isolation
        generationState = state
    }

    func setPipeline(_ pipeline: StableDiffusionPipeline) { // for actor isolation
        sdPipeline = pipeline
        isPipelineCreated = true
    }

    func setGeneratedImages(_ images: GeneratedImages) { // for actor isolation
        generatedImages = images
    }

    // swiftlint:disable function_body_length
    func generateImages(_ parameter: GenerationParameter, modelUrl: URL) {
        guard generationState == .idle else { return }

        currentGenerationParameters = parameter
        Task.detached(priority: .high) {
            await self.setState(.preparation)

            if await self.sdPipeline == nil {
                let config = MLModelConfiguration()
                if !ProcessInfo.processInfo.isiOSAppOnMac {
                    config.computeUnits = .cpuAndGPU
                }

                if let pipeline = try? StableDiffusionPipeline(
                    resourcesAt: modelUrl,
                    configuration: config,
                    disableSafety: true,
                    reduceMemory: true
                ) {
                    await self.setPipeline(pipeline)
                } else {
                    fatalError("Fatal error: failed to create the Stable-Diffusion-Pipeline.")
                }
            }

            if let sdPipeline = await self.sdPipeline {
                do {
                    let seed = UInt32.random(in: 0...UInt32.max)
                    let cgImages = try sdPipeline.generateImages(prompt: parameter.prompt,
                                                                 negativePrompt: parameter.negativePrompt,
                                                                 imageCount: parameter.imageCount,
                                                                 stepCount: parameter.stepCount,
                                                                 seed: seed,
                                                                 disableSafety: parameter.disableSafety,
                                                                 progressHandler: self.progressHandler)
                    print("images were generated.")
                    var uiImages: [UIImage] = []

                    if parameter.isUpscale {
                        if let lastImage = cgImages.compactMap({ $0 }).last {
                            await self.setState(.upscaling(image: lastImage))
                        }

                        for image in cgImages {
                            guard
                                let cgImage = image,
                                let upscaledImage = await self.upscaler.upscale(cgImage: cgImage)
                            else { continue }

                            uiImages.append(UIImage(cgImage: upscaledImage))
                        }
                    } else {
                        uiImages = cgImages.compactMap { image in
                            guard let cgImage = image else { return nil }

                            return UIImage(cgImage: cgImage)
                        }
                    }

                    await self.setGeneratedImages(GeneratedImages(
                        prompt: parameter.prompt,
                        negativePrompt: parameter.negativePrompt,
                        imageCount: parameter.imageCount,
                        stepCount: parameter.stepCount,
                        disableSafety: parameter.disableSafety,
                        images: uiImages.map { uiImage in GeneratedImage(uiImage: uiImage) })
                    )
                } catch {
                    print("failed to generate images.")
                }
            }

            await self.setState(.idle)
        }
    }

    nonisolated func progressHandler(progress: StableDiffusionPipeline.Progress) -> Bool {

            if ProcessInfo.processInfo.isiOSAppOnMac {

            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    let currentImage: CGImage? = {
                        if
                            let parameters = self.currentGenerationParameters,
                            parameters.isShowSteps
                        {
                            return progress.currentImages.last ?? nil
                        } else {
                            return nil
                        }
                    }()

                    self.setState(.generating(
                        progressStep: progress.step,
                        countStep: progress.stepCount,
                        image: currentImage
                    ))
                }
            }

            return true // continue
        }
}
