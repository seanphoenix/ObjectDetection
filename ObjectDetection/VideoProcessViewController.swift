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

    private var photoAlbum: PhotoAlbum?
    private let authHint = UILabel()
    private let imageView = UIImageView()
    private let progressBar = UIProgressView()
    private let recordingIndicator = UIView()
}

// MARK: - UI Layout
private extension VideoProcessViewController {
    /* View hierarchy
     * View
     *  ├ authHint
     *  ├ imageView
     *  | progressBar
     *  └ recordingIndicator
     */
    func setupUI() {
        view.backgroundColor = .black
        setupNav()

        view.addSubview(authHint)
        authHint.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.equalToSuperview().multipliedBy(0.6)
        }
        authHint.text = "Please grant Photo access to save videos with human detected"
        authHint.numberOfLines = 0
        authHint.textAlignment = .center
        authHint.font = .systemFont(ofSize: 20, weight: .medium)
        authHint.textColor = .white
        authHint.isHidden = true

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

        view.addSubview(recordingIndicator)
        recordingIndicator.snp.makeConstraints {
            $0.top.equalTo(progressBar.snp.bottom).offset(16)
            $0.right.equalToSuperview().inset(20)
            $0.height.equalTo(40)
        }
        setup(recordingIndicator: recordingIndicator)
        recordingIndicator.isHidden = true
    }

    func setupNav() {
        title = "Process Video"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(onDone))
        navigationItem.rightBarButtonItem?.isEnabled = false
    }

    /* View hierarchy
     * recordingIndicator
     *  ├ redDot
     *  └ text
     */
    func setup(recordingIndicator: UIView) {
        recordingIndicator.layer.cornerRadius = 20
        recordingIndicator.clipsToBounds = true
        recordingIndicator.layer.borderColor = UIColor.white.cgColor
        recordingIndicator.layer.borderWidth = 2

        let redDot = UIView()
        recordingIndicator.addSubview(redDot)
        redDot.snp.makeConstraints {
            $0.width.height.equalTo(20)
            $0.left.equalToSuperview().inset(10)
            $0.centerY.equalToSuperview()
        }
        redDot.layer.cornerRadius = 10
        redDot.clipsToBounds = true
        redDot.backgroundColor = UIColor(red: 254.0 / 255,
                                         green: 64.0 / 255,
                                         blue: 74.0 / 255,
                                         alpha: 1.0)
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.duration = 1
        anim.fromValue = 1
        anim.toValue = 0.1
        anim.timingFunction = CAMediaTimingFunction(name: .easeIn)
        anim.autoreverses = true
        anim.repeatCount = .infinity
        redDot.layer.add(anim, forKey: "opacity")

        let text = UILabel()
        recordingIndicator.addSubview(text)
        text.snp.makeConstraints {
            $0.left.equalTo(redDot.snp.right).offset(4)
            $0.centerY.equalToSuperview()
            $0.right.equalToSuperview().inset(10)
        }
        text.textColor = .white
        text.text = "REC"
        text.font = .systemFont(ofSize: 20, weight: .medium)
    }
}

// MARK: - Data Binding
private extension VideoProcessViewController {
    func bind() {
        photoAlbum = .init()
        photoAlbum?.authorizationStatusUpdate = { [weak self] authorized in
            if authorized {
            } else {
                self?.authHint.isHidden = false
            }
        }
    }
    }
}

// MARK: - UI Events
private extension VideoProcessViewController {
    @objc
    func onDone() {
        dismiss(animated: true)
    }
}
