//
//  ModelInfo.swift
//  Diffusion
//
//  Created by Pedro Cuenca on 29/12/22.
//  See LICENSE at https://github.com/huggingface/swift-coreml-diffusers/LICENSE
//

import CoreML

let runningOnMac = ProcessInfo.processInfo.isMacCatalystApp

struct ModelInfo {
    /// Hugging Face model Id that contains .zip archives with compiled Core ML models
    let modelId: String
    
    /// Arbitrary string for presentation purposes. Something like "2.1-base"
    let modelVersion: String
    
    /// Whether the archive contains the VAE Encoder (for image to image tasks). Not yet in use.
    let supportsEncoder: Bool
        
    init(modelId: String, modelVersion: String, supportsEncoder: Bool = false) {
        self.modelId = modelId
        self.modelVersion = modelVersion
        self.supportsEncoder = supportsEncoder
    }
}

extension ModelInfo {
    /// Best variant for the current platform.
    /// Currently using `split_einsum` for iOS and `original` for macOS, but could vary depending on model.
    var bestURL: URL {
        // Pattern: https://huggingface.co/dmitrius/coreml-stable-diffusion/resolve/main/coreml-stable-diffusion-v1-5_original_compiled.zip
        let suffix = runningOnMac ? "macos" : "ios"
        return URL(string: "https://huggingface.co/dmitrius/coreml-stable-diffusion/resolve/main/\(modelId)_\(suffix).zip")!
    }
    
    /// Best units for current platform.
    /// Currently using `cpuAndNeuralEngine` for iOS and `cpuAndGPU` for macOS, but could vary depending on model.
    /// .all works for v1.4, but not for v1.5.
    // TODO: measure performance on different devices.
    var bestComputeUnits: MLComputeUnits {
        return runningOnMac ? .cpuAndGPU : .cpuAndNeuralEngine
    }
    
    var reduceMemory: Bool {
        return !runningOnMac
    }
}

extension ModelInfo {
    static let v14Base = ModelInfo(
        modelId: "pcuenq/coreml-stable-diffusion-v1-4",
        modelVersion: "1.4"
    )

    static let v15Base = ModelInfo(
        modelId: "pcuenq/coreml-stable-diffusion-v1-5",
        modelVersion: "1.5"
    )
    
    static let v2Base = ModelInfo(
        modelId: "pcuenq/coreml-stable-diffusion-2-base",
        modelVersion: "2-base"
    )

    static let v21Base = ModelInfo(
        modelId: "stable-diffusion-v2.1-base_split-einsum",
        modelVersion: "2.1-base"
    )
}


