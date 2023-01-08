//
//  ImageGenerator+Models.swift
//  imageAI
//
//  Created by Dmitriy Chervyakov on 31.12.2022.
//

import UIKit

extension ImageGenerator {
    struct GenerationParameter {
        var prompt: String
        var negativePrompt: String
        var stepCount: Int
        var imageCount: Int
        var disableSafety: Bool
        var isShowSteps: Bool
        var isUpscale: Bool
    }

    struct GeneratedImage: Identifiable {
        let id: UUID = UUID()
        let uiImage: UIImage
    }

    struct GeneratedImages {
        let prompt: String
        let negativePrompt: String
        let imageCount: Int
        let stepCount: Int
        let disableSafety: Bool
        let images: [GeneratedImage]
    }

    enum GenerationState: Equatable {
        case idle
        case preparation
        case generating(progressStep: Int, countStep: Int, image: CGImage?)
        case upscaling(image: CGImage)

        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.preparation, .preparation): return true
            case let (.generating(step1, count1, _), .generating(step2, count2, _)):
                if step1 == step2 && count1 == count2 {
                    return true
                } else {
                    return false
                }
            case (.upscaling, .upscaling): return true
            default:
                return false
            }
        }
    }
}
