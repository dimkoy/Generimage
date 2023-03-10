//
//  Upscaler.swift
//  Mochi Diffusion
//
//  Created by Joshua Park on 12/30/22.
//

import Vision
import CoreImage

class Upscaler {
    private var request: VNCoreMLRequest?

    private func loadModel() {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndGPU // Note: CPU & NE conflicts with Image Generation

        // Create a Vision instance using the image classifier's model instance
        guard let model = try? VNCoreMLModel(for: RealESRGAN(configuration: config).model) else {
            fatalError("App failed to create a `VNCoreMLModel` instance.")
        }

        // Create an image classification request with an image classifier model
        request = VNCoreMLRequest(model: model) { request, error in
            if let observations = request.results as? [VNClassificationObservation] {
                print(observations)
            }
        }

        request?.imageCropAndScaleOption = .scaleFit
        request?.usesCPUOnly = false
    }
    
    func upscale(cgImage: CGImage) -> CGImage? {
        loadModel()

        defer {
            request = nil
        }

        guard let request = request else { return nil }

        let handler = VNImageRequestHandler(cgImage: cgImage)
        let requests: [VNRequest] = [request]
        
        try? handler.perform(requests)
        guard let observation = request.results?.first as? VNPixelBufferObservation else { return nil }
        return self.convertPixelBufferToCGImage(pixelBuffer: observation.pixelBuffer)
    }
    
    private func convertPixelBufferToCGImage(pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        return context.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height))
    }
}
