import Testing
import Foundation
import SwiftUI
@testable import Gallery

@Suite
struct GalleryModelTests {
    @Test("Given gallery throws an error, when loadPhotos is called, then the state becomes error")
    func loadPhotos_ErrorState() async {
        // Given
        let mockGallery = MockGallery()
        mockGallery.errorToThrow = Gallery.GalleryError.permissionDenied

        let model = await GalleryModel(gallery: mockGallery)

        // When
        await model.loadPhotos()

        // Then
        let finalState = await model.state
        #expect(finalState == .error(Gallery.GalleryError.permissionDenied), "Model should be in error state")
    }
}
