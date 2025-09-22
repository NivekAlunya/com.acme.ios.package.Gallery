//
//  File.swift
//  Gallery
//
//  Created by Kevin LAUNAY on 03/09/2025.
//

import Foundation
import SwiftUI
@preconcurrency import Photos

public struct PhotoItem: Identifiable, Hashable {
    public let id: String
    public var image: UIImage?
    public let thumb: UIImage
    let asset: PHAsset
    var isSelected: Bool = false
    var isLoading: Bool = false
}

@MainActor
@Observable
class GalleryModel {
    
    enum State: Equatable {
        static func == (lhs: GalleryModel.State, rhs: GalleryModel.State) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading), (.loaded, .loaded), (.displaying, .displaying):
                return true
            case (.error(let e1), .error(let e2)):
                return e1.localizedDescription == e2.localizedDescription
            default:
                return false
            }
        }
        case loading
        case loaded
        case displaying
        case error(Error)
    }
    
    private let gallery: any GalleryProtocol
    private var currentIndex: Int = 0
    
    private(set) var photos: [PhotoItem] = []
    private(set) var photo: PhotoItem? = nil
    private(set) var state: State = .loading
    private let blockSize = 10

    public init(gallery: any GalleryProtocol = Gallery.shared) {
        self.gallery = gallery
    }
    
    func syncPhotos(selectedPhotos: [PhotoItem]) {
        let ids = Set(selectedPhotos.map { $0.id })
        photos = photos.map { photo in
            var mutablePhoto = photo
            mutablePhoto.isSelected = ids.contains(photo.id)
            return mutablePhoto
        }
    }
    
    func loadPhotos() async {
        print("\(type(of: self))-\(#function)")
        do {
            
            let assets = try await gallery.getPhotos()
            
            var loadedPhotos: [PhotoItem] = []
            for asset in assets {
                do {
                    let image = await try gallery.loadThumbnail(from: asset, targetSize: CGSize(width: 200, height: 200))
                    let photoItem = PhotoItem(
                        id: asset.localIdentifier,
                        image: nil,
                        thumb: image,
                        asset: asset
                    )
                    loadedPhotos.append(photoItem)
                } catch {
                    print("Error loading thumbnail for asset \(asset.localIdentifier): \(error)")
                    continue
                }
                
                if loadedPhotos.count % blockSize == 0 {
                    photos.append(contentsOf: loadedPhotos)
                    state = .loaded
                    loadedPhotos.removeAll()
                    // Yield to the main thread to update UI
                    await Task.yield()
                }
                
            }
            
            if !loadedPhotos.isEmpty {
                photos.append(contentsOf: loadedPhotos)
                state = .loaded
            }
        } catch {
            state = .error(error)
            print("Error loading photos: \(error)")
        }
    }
    
    func selectPhotoAtIndex(_ index: Int, selected isSelected: Bool) async {
        do {
            if photos[index].image == nil {
                photos[index].isLoading = true
                photos[index].image = try await gallery.loadImage(from: photos[index].asset)
            }
            photos[index].isLoading = false
            photos[index].isSelected = isSelected
        } catch {
            print("Error updating photo selection at index \(index): \(error)")
        }
        print("Photo at index \(index) is now \(photos[index].isSelected ? "selected" : "deselected")")
    }
    
    func showImageAtIndex(_ index: Int) async {
        guard !photos.isEmpty else {
            print("No photos available to display.")
            return
        }
        currentIndex = switch index {
        case ..<0:
            photos.count - 1
        case photos.count:
            0
        default:
            index
        }

        photo = self.photos[index]
        let delayedLoader = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 500_000_000) // 2 seconds
                // Check if cancelled before doing work
                try Task.checkCancellation()
                
                await MainActor.run {
                    self?.photo?.isLoading = true
                }
            } catch {
                print("Task was cancelled")
            }
        }
        
        do {
            let image = try await gallery.loadImage(from: photo!.asset)
            photo?.image = image
            showImage()
            delayedLoader.cancel()
            photo?.isLoading = false
        } catch {
            print("Error loading full image: \(error)")
        }
    
    }
    func hideImage() {
        photo = nil
    }
    
    func showImage() {
        guard state != .displaying else {
            return
        }
        state = .displaying
    }
    
    func showNextImage() async {
        await showImageAtIndex(currentIndex + 1)
    }
    
    func showPreviousImage() async {
        await showImageAtIndex(currentIndex - 1)
    }
    
    func showGallery() {
        state = .loaded
        photo = nil
    }
}
