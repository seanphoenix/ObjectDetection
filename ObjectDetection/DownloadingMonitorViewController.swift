//
//  DownloadingMonitorViewController.swift
//  ObjectDetection
//
//  Created by Sean Chiu on 2022/7/9.
//  Copyright © 2022 MachineThink. All rights reserved.
//

import Foundation
import UIKit
import SnapKit

// MARK: - DownloadingMonitorViewController
class DownloadingMonitorViewController: UIViewController {
    // MARK: - Constructor
    init(task: DownloadManager.DownloadingTask) {
        self.task = task
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life Cycle
    override func loadView() {
        view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bind(task: task)
    }

    // Internal
    private let task: DownloadManager.DownloadingTask

    private var observation: NSKeyValueObservation?

    private let progressBar = UIProgressView()
    private let filenameLabel = UILabel()
}

// MARK: - UI Layout
private extension DownloadingMonitorViewController {
    /* View hierarchy
     * View
     *  ├ progressBar
     *  └ filenameLabel
     */
    func setupUI() {
        view.addSubview(progressBar)
        progressBar.snp.makeConstraints {
            $0.left.right.equalToSuperview().inset(20)
            $0.top.equalToSuperview().inset(16)
        }

        view.addSubview(filenameLabel)
        filenameLabel.snp.makeConstraints {
            $0.left.right.equalToSuperview().inset(8)
            $0.top.equalTo(progressBar.snp.bottom).offset(8)
            $0.bottom.equalToSuperview().inset(16)
        }
        filenameLabel.numberOfLines = 0
        filenameLabel.textColor = .black
        filenameLabel.textAlignment = .center
    }
}

// MARK: - Data Binding
private extension DownloadingMonitorViewController {
    func bind(task: DownloadManager.DownloadingTask) {
        filenameLabel.text = "Downloading \(task.filename)"
        observation = task.task.progress.observe(\.fractionCompleted) { [weak progressBar] progress, _ in
            DispatchQueue.main.async {
                progressBar?.progress = Float(progress.fractionCompleted)
            }
        }
    }
}
