//
//  TrackLoading.swift
//  ObjectDetection
//
//  Created by Sean Chiu on 2022/7/10.
//  Copyright © 2022 MachineThink. All rights reserved.
//

import Foundation
import AVFoundation

// Ref: https://github.com/rlaguilar/fragmented-MPEG4/blob/d89dd39872c8ea5848bc4bc92c1d6eed7b96eee3/fmp4writer/TrackLoading.swift

struct SourceMedia {
    let asset: AVAsset
    let videoTrack: AVAssetTrack
    let videoTimeScale: CMTimeScale
}

enum LoadTracksError: Error {
    case unknown
    case sourceFileHasNoVideoTrack
}

func loadTracks(assetURL: URL, completion: @escaping (Result<SourceMedia, Error>) -> Void) {
    let asset = AVAsset(url: assetURL)
    let tracksKey = "tracks"

    asset.loadValuesAsynchronously(forKeys: [tracksKey]) {
        do {
            var error: NSError? = nil
            guard asset.statusOfValue(forKey: tracksKey, error: &error) == .loaded else {
                throw error ?? LoadTracksError.unknown
            }

            guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                throw LoadTracksError.sourceFileHasNoVideoTrack
            }

            // Load and validate the video frame rate.
            let minFrameDurationKey = "minFrameDuration"
            let naturalTimeScaleKey = "naturalTimeScale"
            videoTrack.loadValuesAsynchronously(forKeys: [minFrameDurationKey, naturalTimeScaleKey]) {
                do {
                    var error: NSError? = nil
                    guard videoTrack.statusOfValue(forKey: minFrameDurationKey, error: &error) == .loaded else {
                        throw error ?? LoadTracksError.unknown
                    }
                    guard videoTrack.statusOfValue(forKey: naturalTimeScaleKey, error: &error) == .loaded else {
                        throw error ?? LoadTracksError.unknown
                    }
                    DispatchQueue.main.async {
                        completion(.success(.init(asset: asset,
                                                  videoTrack: videoTrack,
                                                  videoTimeScale: videoTrack.naturalTimeScale)))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }

        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
}
