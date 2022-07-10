//
//  PhotoAlbum.swift
//  ObjectDetection
//
//  Created by Sean Chiu on 2022/7/10.
//  Copyright © 2022 MachineThink. All rights reserved.
//

import Foundation
import Photos

enum PhotoAlbumError: Error {
    case albumNotExist
}

// MARK: - PhotoAlbum
class PhotoAlbum {
    var authorizationStatusUpdate: ((Bool) -> Void)? // true for ok

    // MARK: - Public Methods
    func save(url: URL, completion: @escaping ((Bool, Error?) -> Void)) {
        guard let album = album else {
            completion(false, PhotoAlbumError.albumNotExist)
            return
        }
        save(url: url, to: album) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }

    // MARK: - Constructor
    init() {
        checkPermission()
    }

    // Internal
    private var authStatus: Bool? {
        didSet {
            if let status = authStatus {
                DispatchQueue.main.async {
                    self.authorizationStatusUpdate?(status)
                }
            }
        }
    }

    private var album: PHAssetCollection?

    private static let TITLE = "### Human Detection"
}

// MARK: - PhotoLibrary Access Authorization
private extension PhotoAlbum {
    func checkPermission() {
        if #available(iOS 14, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if status == .notDetermined {
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                    if status == .authorized {
                        self.getAlbum()
                        self.authStatus = true
                    } else {
                        self.authStatus = false
                    }
                }
            } else if status == .authorized {
                self.getAlbum()
                authStatus = true
            } else {
                authStatus = false
            }
        } else {
            let status = PHPhotoLibrary.authorizationStatus()
            if status == .notDetermined {
                PHPhotoLibrary.requestAuthorization { status in
                    if status == .authorized {
                        self.getAlbum()
                        self.authStatus = true
                    } else {
                        self.authStatus = false
                    }
                }
            } else if status == .authorized {
                self.getAlbum()
                authStatus = true
            } else {
                authStatus = false
            }
        }
    }
}

// MARK: - Album Creation
private extension PhotoAlbum {
    func getAlbum() {
        DispatchQueue.global().async {
            let options = PHFetchOptions()
            options.predicate = .init(format: "title = %@", PhotoAlbum.TITLE)
            let collections = PHAssetCollection.fetchAssetCollections(with: .album,
                                                                     subtype: .any,
                                                                     options: options)

            if let album = collections.firstObject {
                self.album = album
            } else {
                self.createAlbum()
            }
        }
    }

    func createAlbum() {
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: PhotoAlbum.TITLE)
            placeholder = request.placeholderForCreatedAssetCollection
        } completionHandler: { success, error in
            if success {
                let collections = PHAssetCollection.fetchAssetCollections(
                    withLocalIdentifiers: [placeholder?.localIdentifier ?? ""],
                    options: nil)
                self.album = collections.firstObject
            }
        }
    }
}

// MARK: - Save to Album
private extension PhotoAlbum {
    func save(url: URL, to album: PHAssetCollection, completion: @escaping ((Bool, Error?) -> Void)) {
        DispatchQueue.global().async {
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                guard let placeholder = request?.placeholderForCreatedAsset else {
                    completion(false, nil)
                    return
                }

                let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                albumChangeRequest?.addAssets([placeholder] as NSFastEnumeration)
            } completionHandler: { success, error in
                completion(success, error)
            }
        }
    }
}
