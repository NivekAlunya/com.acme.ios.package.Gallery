//
//  GalleryTests.swift
//  GalleryTests
//
//  Created by Kevin LAUNAY on 03/09/2025.
//

import Testing
import Foundation
import SwiftUI
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
}
