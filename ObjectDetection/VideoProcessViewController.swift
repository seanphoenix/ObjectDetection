//
//  VideoProcessViewController.swift
//  ObjectDetection
//
//  Created by Sean Chiu on 2022/7/10.
//  Copyright © 2022 MachineThink. All rights reserved.
//

import Foundation
import UIKit

// MARK: - VideoProcessViewController
class VideoProcessViewController: UIViewController {
    // MARK: Constructor
    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bind()
    }


    // Internal
    private let url: URL
    private let imageView = UIImageView()
    private let progressBar = UIProgressView()
}

// MARK: - UI Layout
private extension VideoProcessViewController {
    /* View hierarchy
     * View
     *  ├ imageView
     *  └ progressBar
     */
    func setupUI() {
        view.backgroundColor = .black
        setupNav()

        view.addSubview(imageView)
        imageView.snp.makeConstraints {
            $0.left.right.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-20)
        }
        imageView.contentMode = .scaleAspectFit

        view.addSubview(progressBar)
        progressBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.top).inset(24)
            $0.left.right.equalToSuperview().inset(20)
        }
    }

    func setupNav() {
        title = "Process Video"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(onDone))
        navigationItem.rightBarButtonItem?.isEnabled = false
    }
}

// MARK: - Data Binding
private extension VideoProcessViewController {
    func bind() {
    }
}

// MARK: - UI Events
private extension VideoProcessViewController {
    @objc
    func onDone() {
        dismiss(animated: true)
    }
}
