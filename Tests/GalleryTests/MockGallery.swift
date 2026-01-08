import Foundation
import Photos
import UIKit
@testable import Gallery

actor MockGallery: GalleryProtocol {
    var photosToReturn: [PHAsset] = []
    var errorToThrow: Error?
    var thumbnailToReturn: UIImage?
    var onLibraryChangeCallback: (() -> Void)?

    func insertPhoto(data: Data) async throws {
        // Not needed for this test
    }

    func getPhotos() async throws -> [PHAsset] {
        if let error = errorToThrow {
            throw error
        }
        return photosToReturn
    }

    nonisolated func loadImage(from asset: PHAsset, callback: ((UIImage?) -> Void)?) {
        // Not needed for this test
    }

    nonisolated func loadThumbnail(from asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        return thumbnailToReturn
    }

    func setOnLibraryChange(_ onChange: (() -> Void)?) {
        self.onLibraryChangeCallback = onChange
    }
}
