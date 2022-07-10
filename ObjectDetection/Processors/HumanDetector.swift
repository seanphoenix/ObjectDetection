//
//  HumanDetector.swift
//  ObjectDetection
//
//  Created by Sean Chiu on 2022/7/10.
//  Copyright © 2022 MachineThink. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import Vision

enum HumanDetectorError: Error {
    case setupFailed
}

class HumanDetector {
    var progressUpdate: ((Double) -> Void)?
    var frameUpdate: ((UIImage) -> Void)?
    var recordingStatusUpdate: ((Bool) -> Void)?
    var finished: (() -> Void)?

    // MARK: Public Methods
    func cancel() {
        isCancelled = true
    }

    // MARK: Constructor
    init(sourceMedia: SourceMedia) throws {
        let reader = try AVAssetReader(asset: sourceMedia.asset)
        let totalDuration = CMTimeGetSeconds(sourceMedia.videoTrack.timeRange.duration)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)
        ]
        let videoOutput = AVAssetReaderTrackOutput(track: sourceMedia.videoTrack,
                                                   outputSettings: outputSettings)
        videoOutput.alwaysCopiesSampleData = true
        guard reader.canAdd(videoOutput) else {
            throw HumanDetectorError.setupFailed
        }
        reader.add(videoOutput)

        // once the video settings is set, the DecodeTimeStamp and Duration become invalid.
        // create another output to retrieve them.
        let output = AVAssetReaderTrackOutput(track: sourceMedia.videoTrack,
                                              outputSettings: nil)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else {
            throw HumanDetectorError.setupFailed
        }
        reader.add(output)

        guard reader.startReading() else {
            throw HumanDetectorError.setupFailed
        }

        queue.async { [weak self] in
            while self?.isCancelled == false,
                  let sampleBuffer = videoOutput.copyNextSampleBuffer(),
                  let buffer = output.copyNextSampleBuffer() {
                let time = CMSampleBufferGetPresentationTimeStamp(buffer)
                let duration = CMSampleBufferGetDuration(buffer)
                print("time - \(CMTimeGetSeconds(time)) \(time)")
                print("duration - \(CMTimeGetSeconds(duration)) \(duration)")

                let progress = CMTimeGetSeconds(time) / totalDuration
                if !progress.isNaN {
                    DispatchQueue.main.async {
                        self?.progressUpdate?(progress)
                    }
                }

                self?.predict(sampleBuffer: sampleBuffer)
            }
            reader.cancelReading()

            if self?.isCancelled == false {
                DispatchQueue.main.async {
                    self?.finished?()
                }
            }
        }
    }

    // Internal
    private let coreMLModel: MobileNetV2_SSDLite = {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        if #available(iOS 13, *) {
            config.preferredMetalDevice = MTLCreateSystemDefaultDevice()
        }
        return try! MobileNetV2_SSDLite(configuration: config)
    }()

    private lazy var visionModel: VNCoreMLModel = {
        do {
            return try VNCoreMLModel(for: coreMLModel.model)
        } catch {
            fatalError("Failed to create VNCoreMLModel: \(error)")
        }
    }()

    private var isCancelled = false

    private let queue = DispatchQueue(label: "com.seanphoenix.human_detection",
                                      qos: .userInitiated)
    private let renderQueue = DispatchQueue(label: "com.seanphoenix.video_processing",
                                            qos: .userInitiated)
}

// MARK: - Internal
private extension HumanDetector {
    func predict(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Get additional info from the camera.
        var options: [VNImageOption : Any] = [:]
        if let cameraIntrinsicMatrix = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
            options[.cameraIntrinsics] = cameraIntrinsicMatrix
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .up,
                                            options: options)

        let visionRequest = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
            if let error = error {
                print(error)
                return
            }
            self?.processObservations(for: request, with: pixelBuffer)
        }

        // NOTE: If you use another crop/scale option, you must also change
        // how the BoundingBoxView objects get scaled when they are drawn.
        // Currently they assume the full input image is used.
        visionRequest.imageCropAndScaleOption = .scaleFill

        do {
            try handler.perform([visionRequest])
        } catch {
            print("Failed to perform Vision request: \(error)")
        }
    }

    func processObservations(for request: VNRequest, with pixelBuffer: CVPixelBuffer) {
        renderQueue.async {
            if let results = request.results as? [VNRecognizedObjectObservation] {
                self.render(pixelBuffer: pixelBuffer, with: results)
            }

            if let frameUpdate = self.frameUpdate,
               let image = self.renderUIImage(pixelBuffer: pixelBuffer) {
                DispatchQueue.main.async {
                    frameUpdate(image)
                }
            }
        }
    }

    func render(pixelBuffer: CVPixelBuffer, with observed: [VNRecognizedObjectObservation]) {
        let personFound = observed.filter { $0.labels[0].identifier == "person" }
        guard !personFound.isEmpty else { return }

        guard CVPixelBufferLockBaseAddress(pixelBuffer, .init(rawValue: 0)) == kCVReturnSuccess else {
            return
        }

        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .init(rawValue: 0))
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        // make the strokes looks same ratio in different videos
        let strokeWidth = max(CGFloat(min(width, height)) * 0.01, 1)

        let bitmapInfo = CGBitmapInfo(rawValue:
                                        CGBitmapInfo.byteOrder32Little.rawValue |
                                        CGImageAlphaInfo.premultipliedFirst.rawValue)

        guard let data = CVPixelBufferGetBaseAddress(pixelBuffer),
              let context = CGContext(
                data: data,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo.rawValue) else {
            return
        }

        let inset = max(strokeWidth / 2, 1)
        let frame = CGRect(x: 0, y: 0, width: width, height: height)
            .insetBy(dx: inset,
                     dy: inset)

        context.saveGState()
        context.setStrokeColor(UIColor.red.cgColor)
        let scale = CGAffineTransform.identity
            .scaledBy(x: CGFloat(width),
                      y: CGFloat(height))
        personFound
            .map { $0.boundingBox.applying(scale) }
            .map { $0.intersection(frame) }
            .forEach { context.stroke($0, width: strokeWidth) }
        context.restoreGState()
    }

    func renderUIImage(pixelBuffer: CVPixelBuffer) -> UIImage? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        let context = CIContext()
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        guard let cgImage = context.createCGImage(ciImage, from: rect) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: -
private extension HumanDetector {
    func record() {

    }
}
