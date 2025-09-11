// The Swift Programming Language
// https://docs.swift.org/swift-book

@preconcurrency import Photos
import UIKit

public protocol GalleryProtocol: Actor {
    func insertPhoto(data: Data) async throws
    func getPhotos() async throws -> [PHAsset]
    nonisolated func loadImage(from asset: PHAsset, callback: ((UIImage?) -> Void)?)
    nonisolated func loadThumbnail(from asset: PHAsset, targetSize: CGSize) -> UIImage?

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
    }
    
    public static let shared = Gallery()
    private(set) var state: State = .unknown
    private let imageManager = PHImageManager.default()
    
    private override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
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

    nonisolated public func loadThumbnail(from asset: PHAsset, targetSize: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        var uiImage: UIImage?
        imageManager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: options) { image, _ in
            uiImage = image
        }
        return uiImage
    }
    
    nonisolated public func loadImage(from asset: PHAsset, callback: ((UIImage?) -> Void)?) {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        var uiImage: UIImage?
        print("loadImage from asset \(asset.localIdentifier)")
        imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
            print("data for \(asset.localIdentifier) \(data != nil)")
            if let data {
                    uiImage = UIImage(data: data)
            }
            callback?(uiImage)
            print("loadImage from asset \(asset.localIdentifier)")
        }
        print("loadImage from asset \(asset.localIdentifier) ended function")
    }
        
}

extension Gallery: PHPhotoLibraryChangeObserver {
    nonisolated public func photoLibraryDidChange(_ changeInstance: PHChange) {
        // Handle changes to the photo library here
        print("Photo library changed changeInstance: \(changeInstance)" )
    }
}
