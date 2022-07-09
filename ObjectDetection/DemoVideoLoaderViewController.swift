//
//  DemoVideoLoaderViewController.swift
//  ObjectDetection
//
//  Created by Sean Chiu on 2022/7/9.
//  Copyright © 2022 MachineThink. All rights reserved.
//

import Foundation
import UIKit

// MARK: - DemoVideoLoaderViewController
class DemoVideoLoaderViewController: UIViewController {
    // MARK: Life Cycle
    override func loadView() {
        view = tableview
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // Internal
    private let tableview = UITableView()
    private let cellIdentifier = "Cell"

    private let demoFiles = [
        "bolt-detection.mp4",
        "bolt-multi-size-detection.mp4",
        "bottle-detection.mp4",
        "car-detection.mp4",
        "classroom.mp4",
        "face-demographics-walking-and-pause.mp4",
        "face-demographics-walking.mp4",
        "fruit-and-vegetable-detection.mp4",
        "head-pose-face-detection-female-and-male.mp4",
        "head-pose-face-detection-female.mp4",
        "head-pose-face-detection-male.mp4",
        "one-by-one-person-detection.mp4",
        "people-detection.mp4",
        "person-bicycle-car-detection.mp4",
        "store-aisle-detection.mp4",
        "worker-zone-detection.mp4",
    ]

    private let downloadManager = DownloadManager()
}

// MARK: - UITableViewDelegate
extension DemoVideoLoaderViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let filename = demoFiles[indexPath.row]
        let task = downloadManager.fetch(filename: filename) { [weak self] result in
            switch result {
            case let .success(url):
                self?.toProcess(url: url)
            case let .failure(error):
                let ac = UIAlertController(title: nil,
                                           message: error.localizedDescription,
                                           preferredStyle: .alert)
                ac.addAction(.init(title: "OK", style: .default))
                self?.present(ac, animated: true)
            }
        }
        if let task = task {
            // TODO: show downloading progress
        }
    }
}

// MARK: - UITableViewDataSource
extension DemoVideoLoaderViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        demoFiles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableview.dequeueReusableCell(withIdentifier: cellIdentifier,
                                                 for: indexPath)
        cell.textLabel?.text = demoFiles[indexPath.row]
        return cell
    }
}

// MARK: - UI Layout
private extension DemoVideoLoaderViewController {
    func setupUI() {
        setupNav()
        setup(tableview: tableview)
    }

    func setupNav() {
        title = "Select Demo Video"

        let barButton: UIBarButtonItem.SystemItem
        if #available(iOS 13, *) {
            barButton = .close
        } else {
            barButton = .cancel
        }
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: barButton,
                                                           target: self,
                                                           action: #selector(onClose))
    }

    func setup(tableview: UITableView) {
        tableview.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)

        tableview.delegate = self
        tableview.dataSource = self
    }
}

// MARK: - UI Events
private extension DemoVideoLoaderViewController {
    @objc
    func onClose() {
        dismiss(animated: true)
    }
}

// MARK: - Route
private extension DemoVideoLoaderViewController {
    func toProcess(url: URL) {
        // TODO: to process page
    }
}
