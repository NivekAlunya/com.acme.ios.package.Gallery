//
//  GalleryTests.swift
//  GalleryTests
//
//  Created by Kevin LAUNAY on 03/09/2025.
//

import Testing
import Foundation
import SwiftUI
import Photos
@testable import Gallery

@Suite("GalleryModel Tests")
struct GalleryModelTests {

    @Test("Given gallery throws an error, when loadPhotos is called, then the state becomes error")
    func loadPhotos_ErrorState() async {
        // Given
        let mockGallery = MockGallery()
        await mockGallery.setError(Gallery.GalleryError.permissionDenied)

        let model = await GalleryModel(gallery: mockGallery)

        // When
        await model.loadPhotos()

        // Then
        let finalState = await model.state
        #expect(finalState == .error(Gallery.GalleryError.permissionDenied), "Model should be in error state")
    }

    @Test("When photos collection is empty, wrap-around navigation does not crash")
    func emptyGalleryNavigation() async {
        let mockGallery = MockGallery()
        let model = await GalleryModel(gallery: mockGallery)

        await model.showNextImage()
        let photoAfterNext = await model.photo
        #expect(photoAfterNext == nil)

        await model.showPreviousImage()
        let photoAfterPrev = await model.photo
        #expect(photoAfterPrev == nil)
    }

    @Test("Hide image and return to gallery")
    func hideAndReturnToGallery() async {
        let mockGallery = MockGallery()
        let model = await GalleryModel(gallery: mockGallery)

        await model.showGallery()
        let state = await model.state
        #expect(state == .browsing)

        await model.hideImage()
        let photo = await model.photo
        #expect(photo == nil)
    }

    @Test("PhotoItem loadFullImage returns cached image if present")
    func photoItemLoadFullImageCached() async throws {
        let expectedImage = UIImage()
        let item = PhotoItem(
            id: "test-1",
            image: expectedImage,
            thumb: UIImage(),
            asset: PHAsset()
        )
        let loaded = try await item.loadFullImage()
        #expect(loaded == expectedImage)
    }

    @Test("Collection loadFullImages loads all images preserving order")
    func collectionLoadFullImages() async {
        let mockGallery = MockGallery()
        let img1 = UIImage()
        let img2 = UIImage()
        let items = [
            PhotoItem(id: "1", image: img1, thumb: UIImage(), asset: PHAsset()),
            PhotoItem(id: "2", image: nil, thumb: img2, asset: PHAsset())
        ]

        let results = await items.loadFullImages(gallery: mockGallery)
        #expect(results.count == 2)
        #expect(results.first == img1)
    }
}
