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
    var finishedWritingUpdate: ((URL) -> Void)?

    /// Append new frame (CMSampleBuffer) to the write
    /// - Parameter frame: the new frame
    /// - Returns: the total time it records
    func append(sampleBuffer: CMSampleBuffer) throws -> Double {
        guard writer.status == .writing else { throw VideoRecordingError.notWriting }
        if beginTime == nil {
            beginTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        }
        let newBuffer = try sampleBuffer.minusTiming(by: beginTime!)

        // need to wait to get the time length after appended
        while !writerInput.isReadyForMoreMediaData {} // stupid busy loop
        guard writerInput.append(newBuffer) else {
            throw writer.error ?? VideoRecordingError.unknown
        }
        let time = CMSampleBufferGetPresentationTimeStamp(newBuffer)
        return CMTimeGetSeconds(time)
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
            print("\(#file) \(#function) finish writing")
            if self.writer.status == .completed {
                print("\(#file) \(#function) finish writing complete")
                DispatchQueue.main.async {
                    self.finishedWritingUpdate?(self.writer.outputURL)
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
    private var beginTime: CMTime?
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

enum CMSampleBufferCustomError: Error {
    case createBufferFailed
}

private extension CMSampleBuffer {
    func minusTiming(by offset: CMTime) throws -> CMSampleBuffer {
        var itemCount: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(
            self,
            entryCount: 0,
            arrayToFill: nil,
            entriesNeededOut: &itemCount)
        var timingInfo = [CMSampleTimingInfo](repeating: .init(), count: itemCount)
        CMSampleBufferGetSampleTimingInfoArray(
            self,
            entryCount: itemCount,
            arrayToFill: &timingInfo,
            entriesNeededOut: &itemCount)

        timingInfo = timingInfo.map {
            var newSampleTiming = $0
            newSampleTiming.presentationTimeStamp = $0.presentationTimeStamp - offset
            if $0.decodeTimeStamp.isValid {
                newSampleTiming.decodeTimeStamp = $0.decodeTimeStamp - offset
            }
            return newSampleTiming
        }

        var newBuffer: CMSampleBuffer?
        let result = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: self,
            sampleTimingEntryCount: itemCount,
            sampleTimingArray: timingInfo,
            sampleBufferOut: &newBuffer)

        guard result == noErr,
              let newBuffer = newBuffer else {
            throw CMSampleBufferCustomError.createBufferFailed
        }
        let oldOutputPresentationTimeStamp = CMSampleBufferGetOutputPresentationTimeStamp(newBuffer)
        CMSampleBufferSetOutputPresentationTimeStamp(
            newBuffer,
            newValue: oldOutputPresentationTimeStamp - offset)
        return newBuffer
    }
}
