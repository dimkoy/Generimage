//
//  AppState.swift
//  imageAI
//
//  Created by Dmitriy Chervyakov on 06.01.2023.
//

import Foundation
import Path
import ZIPFoundation

import Combine

final class AppState: ObservableObject {
    @Published var state: PipelinePreparationPhase

    enum PipelinePreparationPhase {
        case undetermined
        case waitingToDownload
        case downloading(percent: Double, downloaded: Int, total: Int)
        case downloaded
        case uncompressing(Double)
        case readyOnDisk
        case failed(Error)
    }

    static let models = Path.applicationSupport / "diffusion-models"

    let model: ModelInfo
    private var downloadSubscriber: Cancellable?

    var url: URL {
        return model.bestURL
    }

    var filename: String {
        return url.lastPathComponent
    }

    var packagesFilename: String { downloadedPath.basename(dropExtension: true) }
    var downloadedPath: Path { AppState.models / filename }
    var downloadedURL: URL { downloadedPath.url }
    var uncompressPath: Path { downloadedPath.parent }
    var compiledPath: Path { downloadedPath.parent / packagesFilename }

    init(model: ModelInfo) {
        self.model = model
        state = .undetermined
        setInitialState()
    }

    func setInitialState() {
        if ready {
            state = .readyOnDisk
            return
        }
        if downloaded {
            state = .downloaded
            return
        }
        state = .waitingToDownload
    }

    var ready: Bool {
        return compiledPath.exists
    }

    var downloaded: Bool {
        return downloadedPath.exists
    }

    func prepare() async {
        do {
            try AppState.models.mkdir(.p)
            try await download()
            try await unzip()
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.state = .failed(error)
            }
        }
    }

    @discardableResult
    func download() async throws -> URL {
        if ready || downloaded { return downloadedURL }

        let downloader = Downloader(from: url, to: downloadedURL)
        downloadSubscriber = downloader.downloadState.sink { state in
            if case let .downloading(progress, downloaded, total) = state {
                let percent = (progress * 10000).rounded() / 10000
                DispatchQueue.main.async {
                    self.state = .downloading(percent: percent, downloaded: downloaded, total: total)
                }
            }
        }
        try downloader.waitUntilDone()
        return downloadedURL
    }

    func unzip() async throws {
        guard downloaded else { return }

        let unzipProgress = Progress()

        let observation = unzipProgress.observe(\.fractionCompleted) { progress, _ in
            let percent = (progress.fractionCompleted * 1000).rounded() / 1000
            DispatchQueue.main.async {
                self.state = .uncompressing(percent)
            }
        }

        do {
            try FileManager().unzipItem(at: downloadedURL, to: uncompressPath.url, progress: unzipProgress)
        } catch {
            // Cleanup if error occurs while unzipping
            try uncompressPath.delete()
            observation.invalidate()
            throw error
        }
        try downloadedPath.delete()
        observation.invalidate()

        DispatchQueue.main.async {
            self.state = .readyOnDisk
        }
    }
}
