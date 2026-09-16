//
//  Gallery.swift
//  Gallery
//
//  Created by Kevin LAUNAY on 03/09/2025.
//

@preconcurrency import Photos
import UIKit

/// Protocol defining the interface for gallery photo storage and retrieval.
public protocol GalleryProtocol: Actor {
    /// Inserts a photo into the photo library from encoded data.
    func insertPhoto(data: Data) async throws
    /// Fetches all image assets from the photo library.
    func getPhotos() async throws -> [PHAsset]
    /// Loads a full image asynchronously for the specified asset.
    nonisolated func loadImage(from asset: PHAsset) async throws -> UIImage
    /// Loads a thumbnail asynchronously for the specified asset.
    nonisolated func loadThumbnail(from asset: PHAsset, targetSize: CGSize) async throws -> UIImage
}

/// An actor managing photo library interactions, asset querying, and asynchronous image retrieval.
public actor Gallery: NSObject {
    /// Authorization status of photo library access.
    public enum State: Sendable {
        case unauthorized
        case authorized
        case limited
        case unknown
        case notDetermined
    }
    
    /// Errors that can occur during photo library operations.
    public enum GalleryError: Error, Sendable, Equatable {
        case permissionDenied
        case insertionFailed(String)
        case loadingThumbnailFailed
        case loadingImageFailed

        public static func == (lhs: GalleryError, rhs: GalleryError) -> Bool {
            switch (lhs, rhs) {
            case (.permissionDenied, .permissionDenied),
                 (.loadingThumbnailFailed, .loadingThumbnailFailed),
                 (.loadingImageFailed, .loadingImageFailed):
                return true
            case (.insertionFailed(let a), .insertionFailed(let b)):
                return a == b
            default:
                return false
            }
        }
    }
    
    public static let shared = Gallery()
    public private(set) var state: State = .unknown
    private let imageManager = PHImageManager.default()
    private let cachingManager = PHCachingImageManager()
    private var onLibraryChange: (() -> Void)?
    private var cachedAssets: [PHAsset] = []
    private let targetSize = CGSize(width: 200, height: 200)
    
    private override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
        cachingManager.startCachingImages(for: cachedAssets, targetSize: targetSize, contentMode: .aspectFill, options: nil)
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    func savePhoto(data: Data) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let options = PHAssetResourceCreationOptions()
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: data, options: options)
        }
    }
    
    /// Checks or requests user authorization for photo library access, returning the granular `State`.
    @discardableResult
    public func checkOrRequestPermission() async -> State {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if currentStatus == .authorized || currentStatus == .limited {
            let newState: State = (currentStatus == .authorized) ? .authorized : .limited
            self.state = newState
            return newState
        }
        
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        switch status {
        case .authorized:
            self.state = .authorized
            return .authorized
        case .limited:
            self.state = .limited
            return .limited
        case .denied, .restricted:
            self.state = .unauthorized
            return .unauthorized
        case .notDetermined:
            self.state = .notDetermined
            return .notDetermined
        @unknown default:
            self.state = .unknown
            return .unknown
        }
    }

    /// Requests user authorization to read and write to the photo library.
    /// - Returns: `true` if authorized or access is limited; `false` otherwise.
    @discardableResult
    public func askForPermission() async -> Bool {
        let status = await checkOrRequestPermission()
        return status == .authorized || status == .limited
    }
}

extension Gallery: GalleryProtocol {
    
    /// Fetches all image assets from the user's photo library, sorted by creation date descending.
    /// - Throws: `GalleryError.permissionDenied` if user access was not granted.
    public func getPhotos() async throws -> [PHAsset] {
        guard await askForPermission() else {
            throw GalleryError.permissionDenied
        }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        var assets: [PHAsset] = []
        PHAsset
            .fetchAssets(with: .image, options: fetchOptions)
            .enumerateObjects { asset, _, _ in
                assets.append(asset)
            }
        return assets
    }
    
    /// Inserts raw image data into the photo library.
    /// - Parameter data: Encoded image data (e.g. JPEG or PNG).
    public func insertPhoto(data: Data) async throws {
        guard await askForPermission() else {
            throw GalleryError.permissionDenied
        }
        
        do {
            try await savePhoto(data: data)
        } catch {
            throw GalleryError.insertionFailed(error.localizedDescription)
        }
    }

    /// Loads a thumbnail for the specified asset asynchronously without blocking the cooperative thread pool.
    /// - Parameters:
    ///   - asset: The asset to generate a thumbnail for.
    ///   - targetSize: Target thumbnail dimensions.
    /// - Returns: The loaded thumbnail image.
    nonisolated public func loadThumbnail(from asset: PHAsset, targetSize: CGSize = CGSize(width: 200, height: 200)) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true

            var hasResumed = false
            self.imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, info in
                if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                    return // Ignore low-res preliminary callback
                }
                guard !hasResumed else { return }
                hasResumed = true

                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let isCancelled = info?[PHImageCancelledKey] as? Bool, isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: GalleryError.loadingThumbnailFailed)
                }
            }
        }
    }
    
    /// Asynchronously fetches the full image data for the specified asset without blocking cooperative threads.
    /// - Parameter asset: The photo library asset.
    /// - Returns: The decoded `UIImage`.
    nonisolated public func loadImage(from asset: PHAsset) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true

            var hasResumed = false
            self.imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                    return // Ignore low-res preliminary callback
                }
                guard !hasResumed else { return }
                hasResumed = true

                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let isCancelled = info?[PHImageCancelledKey] as? Bool, isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else if let data, let image = UIImage(data: data) {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: GalleryError.loadingImageFailed)
                }
            }
        }
    }
}

extension Gallery: PHPhotoLibraryChangeObserver {
    nonisolated public func photoLibraryDidChange(_ changeInstance: PHChange) {
        // Observers can be notified here when the library changes
    }
}
