//
//  DownloadManager.swift
//  ObjectDetection
//
//  Created by Sean Chiu on 2022/7/9.
//  Copyright © 2022 MachineThink. All rights reserved.
//

import Foundation

enum DownloadManagerError: Error {
    case unknown
}

class DownloadManager {
    class DownloadingTask {
        let filename: String
        let task: URLSessionDownloadTask

        fileprivate var completions = [(Result<URL, Error>) -> Void]()

        init(filename: String, task: URLSessionDownloadTask) {
            self.filename = filename
            self.task = task
        }

        fileprivate func finished(result: Result<URL, Error>) {
            completions.forEach { $0(result) }
        }
    }

    func fetch(filename: String, completion: @escaping (Result<URL, Error>) -> Void) -> DownloadingTask? {
        if let url = findInDocument(filename: filename) {
            print("\(filename) is downloaded")
            completion(.success(url))
            return nil
        }

        if let currentDownloadingTask = tasks.first(where: { $0.filename == filename }) {
            print("\(filename) is downloading, appending to current task")
            currentDownloadingTask.completions.append(completion)
            return currentDownloadingTask
        }

        let targetURL = domain.appendingPathComponent(filename)
        let saveToURL = documentPath.appendingPathComponent(filename)
        print("targetURL \(targetURL)")
        print("saveToURL \(saveToURL)")
        let task = session.downloadTask(with: targetURL) { [weak self] tempLocalURL, response, error in
            do {
                if let error = error {
                    throw error
                }

                guard let tempLocalURL = tempLocalURL else {
                    throw DownloadManagerError.unknown
                }

                let fm = FileManager.default
                try fm.copyItem(at: tempLocalURL, to: saveToURL)
                print("\(filename) finished download")
                self?.finished(filename: filename, result: .success(saveToURL))
            } catch {
                print("\(filename) downloading failed")
                self?.finished(filename: filename, result: .failure(error))
            }
        }
        let downloadingTask = DownloadingTask(filename: filename, task: task)
        downloadingTask.completions.append(completion)
        tasks.append(downloadingTask)
        task.resume()
        return downloadingTask
    }

    private let domain = URL(string: "https://raw.githubusercontent.com/intel-iot-devkit/sample-videos/master/")!
    private let session = URLSession(configuration: .default)
    private var tasks = [DownloadingTask]() {
        didSet {
            print("tasks count \(tasks.count)")
        }
    }
}

// MARK: File
private extension DownloadManager {
    var documentPath: URL {
        let paths = NSSearchPathForDirectoriesInDomains(
            .documentDirectory,
            .userDomainMask,
            true)
        assert(!paths.isEmpty)
        let path = paths[0]
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    func findInDocument(filename: String) -> URL? {
        let path = documentPath.appendingPathComponent(filename)
        let fm = FileManager.default
        if fm.fileExists(atPath: path.path) {
            return path
        }
        return nil
    }
}

// MARK: Download Task
private extension DownloadManager {
    func finished(filename: String, result: Result<URL, Error>) {
        DispatchQueue.main.async {
            let current = self.tasks.filter { $0.filename == filename }
            current.forEach { $0.finished(result: result) }
            self.tasks = self.tasks.filter { $0.filename != filename }
        }
    }
}
