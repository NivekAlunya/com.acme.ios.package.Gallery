// The Swift Programming Language
// https://docs.swift.org/swift-book

@preconcurrency import Photos
import UIKit

public protocol GalleryProtocol: Actor {
    func insertPhoto(data: Data) async throws
    func getPhotos() async throws -> [PHAsset]
    nonisolated func loadImage(from asset: PHAsset) async throws -> UIImage
    nonisolated func loadThumbnail(from asset: PHAsset, targetSize: CGSize) async throws -> UIImage
}

public actor Gallery: NSObject {
    enum State {
        case unauthorized
        case authorized
        case limited
        case unknown
        case notDetermined
    }
    
    enum GalleryError: Error {
        case permissionDenied
        case insertionFailed
        case loadingThumbnailFailed
        case loadingImageFailed
    }
    
    public static let shared = Gallery()
    private(set) var state: State = .unknown
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
    
    func savePhoto(data : Data) async throws {
        
        try await PHPhotoLibrary.shared().performChanges {
            let options = PHAssetResourceCreationOptions()
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: data, options: options)
        }
    }
    
    func askForPermission() async -> Bool {
        let authorized = PHPhotoLibrary.authorizationStatus(for: .addOnly) == .authorized
        guard !authorized else {
            state = .authorized
            return true
        }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        switch status {
        case .authorized:
            self.state = .authorized
            print("Access granted to photo library")
            return true
        case .denied, .restricted:
            self.state = .unauthorized
            print("Access denied or restricted")
            return false
        case .notDetermined:
            self.state = .notDetermined
            print("Permission not determined")
            return false
        case .limited:
            self.state = .limited
            print("Limited access granted")
            return true
        @unknown default:
            self.state = .unknown
            print("Unknown status")
            return false
        }
    }
}

extension Gallery: GalleryProtocol {
    
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
    
    public func insertPhoto(data: Data) async throws {
        // Code to insert photo into the gallery
        guard await askForPermission() else {
            throw GalleryError.permissionDenied
        }
        
        do {
            try await savePhoto(data: data)
        } catch {
            throw GalleryError.insertionFailed
        }
    }

    nonisolated public func loadThumbnail(from asset: PHAsset, targetSize: CGSize = CGSize(width: 200, height: 200)) async throws -> UIImage {
        
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isSynchronous = true
                options.isNetworkAccessAllowed = true
                print("loadThumbnail from asset \(asset.localIdentifier)")
                imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, info in
                    print("thumbnail for \(asset.localIdentifier) \(image != nil)")
                    guard let image else  {
                        continuation.resume(throwing: GalleryError.loadingThumbnailFailed)
                        return
                    }
                    continuation.resume(returning: image)
                    print("loadThumbnail from asset \(asset.localIdentifier) ended function")
                }
            }
        }
    }
    
    nonisolated public func loadImage(from asset: PHAsset) async throws -> UIImage {
        
        return try await withCheckedThrowingContinuation { continuation in
            
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            var uiImage: UIImage?
            print("loadImage from asset \(asset.localIdentifier)")
            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                    guard let data
                    , let uiImage = UIImage(data: data) else  {
                        continuation.resume(throwing: GalleryError.loadingImageFailed)
                        return
                    }
                    print("data for \(asset.localIdentifier) \(data != nil)")
                    continuation.resume(returning: uiImage)
                    print("loadImage from asset \(asset.localIdentifier)")
            }
        }
    }
        
}

extension Gallery: PHPhotoLibraryChangeObserver {
    nonisolated public func photoLibraryDidChange(_ changeInstance: PHChange) {
        print("Photo library did change")
    }

}
