//
//  GalleryModel.swift
//  Gallery
//
//  Created by Kevin LAUNAY on 03/09/2025.
//

import Foundation
import SwiftUI
@preconcurrency import Photos
import os

private let logger = Logger(subsystem: "com.acme.ios.package.Gallery", category: "GalleryModel")

/// Represents an individual photo item in the gallery, including thumbnails and full images.
public struct PhotoItem: Identifiable, Hashable, Sendable {
    public let id: String
    public var image: UIImage?
    public let thumb: UIImage
    public let asset: PHAsset
    public var isSelected: Bool
    public var isLoading: Bool

    public init(
        id: String,
        image: UIImage? = nil,
        thumb: UIImage,
        asset: PHAsset,
        isSelected: Bool = false,
        isLoading: Bool = false
    ) {
        self.id = id
        self.image = image
        self.thumb = thumb
        self.asset = asset
        self.isSelected = isSelected
        self.isLoading = isLoading
    }
}

/// The presentation model managing photo loading, selection, and fullscreen navigation.
@MainActor
@Observable
final class GalleryModel {
    
    /// Observable state representing the gallery's current operational status.
    enum State: Equatable, Sendable {
        static func == (lhs: GalleryModel.State, rhs: GalleryModel.State) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading), (.browsing, .browsing):
                return true
            case (.displaying(let leftIsLoading), .displaying(let rightIsLoading)):
                return leftIsLoading == rightIsLoading
            case (.error(let e1), .error(let e2)):
                return e1.localizedDescription == e2.localizedDescription
            default:
                return false
            }
        }
        case loading
        case browsing
        case displaying(isLoading: Bool)
        case error(Error)
    }
    
    private let gallery: any GalleryProtocol
    private var currentIndex: Int = 0
    
    private(set) var photos: [PhotoItem] = []
    private(set) var photo: PhotoItem? = nil
    private(set) var state: State = .loading
    private let blockSize = 10

    /// Initializes a `GalleryModel` with the provided gallery service.
    /// - Parameter gallery: Gallery service conforming to `GalleryProtocol` (default: `Gallery.shared`).
    init(gallery: any GalleryProtocol = Gallery.shared) {
        self.gallery = gallery
    }
    
    /// Synchronizes selection status with an external list of selected photos.
    /// - Parameter selectedPhotos: Selected photo items to match against.
    func syncPhotos(selectedPhotos: [PhotoItem]) {
        let ids = Set(selectedPhotos.map { $0.id })
        photos = photos.map { photo in
            var mutablePhoto = photo
            mutablePhoto.isSelected = ids.contains(photo.id)
            return mutablePhoto
        }
    }
    
    /// Fetches assets from the photo library and loads initial thumbnails in batches.
    func loadPhotos() async {
        logger.debug("loadPhotos()")
        do {
            let assets = try await gallery.getPhotos()
            var loadedPhotos: [PhotoItem] = []
            state = .browsing

            for asset in assets {
                do {
                    let image = try await gallery.loadThumbnail(from: asset, targetSize: CGSize(width: 200, height: 200))
                    let photoItem = PhotoItem(
                        id: asset.localIdentifier,
                        image: nil,
                        thumb: image,
                        asset: asset
                    )
                    loadedPhotos.append(photoItem)
                } catch {
                    logger.error("Error loading thumbnail for asset \(asset.localIdentifier): \(error.localizedDescription)")
                    continue
                }
                
                if loadedPhotos.count % blockSize == 0 {
                    photos.append(contentsOf: loadedPhotos)
                    loadedPhotos.removeAll()
                    // Yield to the main actor to allow UI updates
                    await Task.yield()
                }
            }
            
            if !loadedPhotos.isEmpty {
                photos.append(contentsOf: loadedPhotos)
            }
        } catch {
            state = .error(error)
            logger.error("Error loading photos: \(error.localizedDescription)")
        }
    }
    
    /// Selects or deselects the photo at the specified index, loading its full image if needed.
    /// - Parameters:
    ///   - index: The index of the photo in the collection.
    ///   - isSelected: The target selection state.
    func selectPhotoAtIndex(_ index: Int, selected isSelected: Bool) async {
        guard photos.indices.contains(index) else { return }
        do {
            if photos[index].image == nil {
                photos[index].isLoading = true
                photos[index].image = try await gallery.loadImage(from: photos[index].asset)
            }
            photos[index].isLoading = false
            photos[index].isSelected = isSelected
        } catch {
            logger.error("Error updating photo selection at index \(index): \(error.localizedDescription)")
        }
        logger.debug("Photo at index \(index) is now \(self.photos[index].isSelected ? "selected" : "deselected")")
    }
    
    /// Prepares and presents the photo at the given index, wrapping safely around collection bounds.
    /// - Parameter index: Target photo index. Wrap-around navigation is supported.
    func showImageAtIndex(_ index: Int) async {
        guard !photos.isEmpty else {
            logger.warning("No photos available to display.")
            return
        }
        // Mathematical Euclidean modulo for circular wrap-around navigation:
        // In Swift, `%` is a remainder operator (e.g. -1 % 5 == -1, which causes out-of-bounds crashes).
        // The formula `(index % count + count) % count` ensures negative values wrap backwards
        // (e.g. -1 -> count - 1) and out-of-bounds values wrap forward (e.g. count -> 0).
        currentIndex = (index % photos.count + photos.count) % photos.count

        photo = self.photos[currentIndex]
        let delayedLoader = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                try Task.checkCancellation()
                
                await MainActor.run {
                    self?.state = .displaying(isLoading: true)
                    self?.photo?.isLoading = true
                }
            } catch {
                logger.debug("Task was cancelled")
            }
        }
        
        guard let asset = photo?.asset else {
            delayedLoader.cancel()
            return
        }

        do {
            let image = try await gallery.loadImage(from: asset)
            delayedLoader.cancel()
            photo?.image = image
            state = .displaying(isLoading: false)
            photo?.isLoading = false
        } catch {
            delayedLoader.cancel()
            logger.error("Error loading full image: \(error.localizedDescription)")
        }
    }

    /// Hides the current fullscreen photo.
    func hideImage() {
        photo = nil
    }
        
    /// Navigates to the next image in the collection, wrapping to the start if at the end.
    func showNextImage() async {
        await showImageAtIndex(currentIndex + 1)
    }
    
    /// Navigates to the previous image in the collection, wrapping to the end if at the start.
    func showPreviousImage() async {
        await showImageAtIndex(currentIndex - 1)
    }
    
    /// Returns the gallery state to browsing mode.
    func showGallery() {
        state = .browsing
        photo = nil
    }

    #if DEBUG
    func setPhotosForTesting(_ photos: [PhotoItem]) {
        self.photos = photos
    }
    #endif
}
