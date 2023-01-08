//
//  Downloader.swift
//  imageAI
//
//  Created by Dmitriy Chervyakov on 06.01.2023.
//

import Foundation
import Combine
import Path

class Downloader: NSObject, ObservableObject {
    private(set) var destination: URL

    enum DownloadState {
        case notStarted
        case downloading(Double, Int, Int)
        case completed(URL)
        case failed(Error)
    }

    private(set) lazy var downloadState: CurrentValueSubject<DownloadState, Never> = CurrentValueSubject(.notStarted)
    private var stateSubscriber: Cancellable?

    init(from url: URL, to destination: URL) {
        self.destination = destination
        super.init()

        // .background allows downloads to proceed in the background
        let config = URLSessionConfiguration.background(withIdentifier: "com.dmitrii.diffusion.download")
        let urlSession = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
        downloadState.value = .downloading(0, 0, 0)
        urlSession.getAllTasks { tasks in
            // If there's an existing pending background task, let it proceed, otherwise start a new one.
            // TODO: check URL when we support downloading more models.
            if tasks.first == nil {
                let downloadTask = urlSession.downloadTask(with: url)
                downloadTask.countOfBytesClientExpectsToReceive = 2_330_000_000
                downloadTask.resume()
            }
        }
    }

    @discardableResult
    func waitUntilDone() throws -> URL {
        // It's either this, or stream the bytes ourselves (add to a buffer, save to disk, etc; boring and finicky)
        let semaphore = DispatchSemaphore(value: 0)
        stateSubscriber = downloadState.sink { state in
            switch state {
            case .completed: semaphore.signal()
            case .failed:    semaphore.signal()
            default:         break
            }
        }
        semaphore.wait()

        switch downloadState.value {
        case .completed(let url): return url
        case .failed(let error):  throw error
        default: throw NSError(domain: "Can't happen", code: 100)
        }
    }
}

extension Downloader: URLSessionDelegate, URLSessionDownloadDelegate {
    func urlSession(
        _: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData _: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        downloadState.value = .downloading(
            Double(totalBytesWritten) / Double(totalBytesExpectedToWrite),
            Int(totalBytesWritten),
            Int(totalBytesExpectedToWrite)
        )
    }

    func urlSession(_: URLSession, downloadTask _: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let path = Path(url: location) else {
            downloadState.value = .failed("Invalid download location received: \(location)")
            return
        }
        guard let toPath = Path(url: destination) else {
            downloadState.value = .failed("Invalid destination: \(destination)")
            return
        }
        do {
            try path.move(to: toPath, overwrite: true)

            downloadState.value = .completed(destination)
        } catch {
            downloadState.value = .failed(error)
        }
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            downloadState.value = .failed(error)
        }
    }
}
