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
    public enum GalleryError: Error, Sendable {
        case permissionDenied
        case insertionFailed
        case loadingThumbnailFailed
        case loadingImageFailed
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
    
    /// Requests user authorization to read and write to the photo library.
    /// - Returns: `true` if authorized or access is limited; `false` otherwise.
    public func askForPermission() async -> Bool {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if currentStatus == .authorized || currentStatus == .limited {
            self.state = (currentStatus == .authorized) ? .authorized : .limited
            return true
        }
        
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        switch status {
        case .authorized:
            self.state = .authorized
            return true
        case .limited:
            self.state = .limited
            return true
        case .denied, .restricted:
            self.state = .unauthorized
            return false
        case .notDetermined:
            self.state = .notDetermined
            return false
        @unknown default:
            self.state = .unknown
            return false
        }
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
            throw GalleryError.insertionFailed
        }
    }

    /// Loads a thumbnail for the specified asset.
    /// - Parameters:
    ///   - asset: The asset to generate a thumbnail for.
    ///   - targetSize: Target thumbnail dimensions.
    /// - Returns: The loaded thumbnail image.
    nonisolated public func loadThumbnail(from asset: PHAsset, targetSize: CGSize = CGSize(width: 200, height: 200)) async throws -> UIImage {
        try await Task.detached(priority: .userInitiated) {
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = true
            options.isNetworkAccessAllowed = true

            var resultImage: UIImage?
            self.imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
                resultImage = image
            }

            guard let resultImage else {
                throw GalleryError.loadingThumbnailFailed
            }
            return resultImage
        }.value
    }
    
    /// Asynchronously fetches the full image data for the specified asset.
    /// - Parameter asset: The photo library asset.
    /// - Returns: The decoded `UIImage`.
    nonisolated public func loadImage(from asset: PHAsset) async throws -> UIImage {
        try await Task.detached(priority: .userInitiated) {
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = true
            options.isNetworkAccessAllowed = true

            var resultImage: UIImage?
            self.imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                if let data {
                    resultImage = UIImage(data: data)
                }
            }

            guard let resultImage else {
                throw GalleryError.loadingImageFailed
            }
            return resultImage
        }.value
    }
}

extension Gallery: PHPhotoLibraryChangeObserver {
    nonisolated public func photoLibraryDidChange(_ changeInstance: PHChange) {
        // Observers can be notified here when the library changes
    }
}
