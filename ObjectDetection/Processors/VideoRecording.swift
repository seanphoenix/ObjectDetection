//
//  VideoRecording.swift
//  ObjectDetection
//
//  Created by Sean Chiu on 2022/7/11.
//  Copyright © 2022 MachineThink. All rights reserved.
//

import Foundation
import AVFoundation
import VideoToolbox

enum VideoRecordingError: Error {
    case unknown
    case setupFailed
    case cannotStartWriting
    case notWriting
}

class VideoRecording {
    var finishedWritingUpdate: (() -> Void)?

    /// Append new frame (CMSampleBuffer) to the write
    /// - Parameter frame: the new frame
    /// - Returns: the total time it records
    func append(frame: CMSampleBuffer) throws -> Double {
        guard writer.status == .writing else { throw VideoRecordingError.notWriting }
        while !writerInput.isReadyForMoreMediaData {} // stupid busy loop
        guard writerInput.append(frame) else { throw writer.error ?? VideoRecordingError.unknown }
        let duration = CMTimeGetSeconds(writer.overallDurationHint)
        print(">>> duration \(duration)")
        return duration
    }

    /// Cancel the recording
    func cancel() {
        guard writer.status == .writing else { return }
        writer.cancelWriting()
    }

    /// Finish the recording
    func finish() {
        guard writer.status == .writing else { return }
        writer.finishWriting {
            if self.writer.status == .completed {
                DispatchQueue.main.async {
                    self.finishedWritingUpdate?()
                }
            }
        }
    }

    // MARK: Constructor
    init(width: Int, height: Int, sourceMedia: SourceMedia) throws {
        let path = cachePath()
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        let writer = try AVAssetWriter(url: path, fileType: .init(AVFileType.mp4.rawValue))

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                kVTCompressionPropertyKey_AverageBitRate: 6000000,
                kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_H264_High_4_1
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.mediaTimeScale = sourceMedia.videoTimeScale
        guard writer.canAdd(input) else { throw VideoRecordingError.setupFailed }
        writer.add(input)
        self.writerInput = input
        self.writer = writer

        guard writer.startWriting() else { throw writer.error ?? VideoRecordingError.cannotStartWriting }

        writer.startSession(atSourceTime: .zero)
    }

    private let writer: AVAssetWriter
    private let writerInput: AVAssetWriterInput

    private let queue = DispatchQueue(label: "com.seanphoenix.writer",
                                      qos: .userInitiated)
}


private func cachePath() -> URL {
    let pathStr = NSSearchPathForDirectoriesInDomains(
        .cachesDirectory,
        .userDomainMask,
        true)[0]
    let url = URL(fileURLWithPath: pathStr, isDirectory: true)
    let fm = FileManager.default
    try! fm.createDirectory(at: url,
                            withIntermediateDirectories: true,
                            attributes: nil)
    return url
}
