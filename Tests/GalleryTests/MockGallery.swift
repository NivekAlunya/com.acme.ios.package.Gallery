//
//  MockGallery.swift
//  GalleryTests
//
//  Created by Kevin LAUNAY on 03/09/2025.
//

import Foundation
import Photos
import UIKit
@testable import Gallery

actor MockGallery: GalleryProtocol {
    private var photosToReturn: [PHAsset] = []
    private var errorToThrow: Error?

    init() {}

    func setPhotos(_ photos: [PHAsset]) {
        self.photosToReturn = photos
    }

    func setError(_ error: Error?) {
        self.errorToThrow = error
    }

    func insertPhoto(data: Data) async throws {
        if let error = errorToThrow {
            throw error
        }
    }

    func getPhotos() async throws -> [PHAsset] {
        if let error = errorToThrow {
            throw error
        }
        return photosToReturn
    }

    nonisolated func loadImage(from asset: PHAsset) async throws -> UIImage {
        return UIImage()
    }

    nonisolated func loadThumbnail(from asset: PHAsset, targetSize: CGSize) async throws -> UIImage {
        return UIImage()
    }
}
