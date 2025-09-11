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
}

@MainActor
public class GalleryModel: ObservableObject {
    
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
    
    @Published private(set) var photos: [PhotoItem] = []
    @Published private(set) var photo: PhotoItem? = nil
    @Published private(set) var state: State = .loading
    @Published private(set) var isImageLoading = false
    
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
            
            photos = assets.compactMap { asset in
                if let image = gallery.loadThumbnail(from: asset, targetSize: CGSize(width: 200, height: 200)) {
                    return PhotoItem(
                        id: asset.localIdentifier
                        , image: nil
                        , thumb: image
                        , asset: asset)
                } else {
                    return nil
                }
            }
            state = .loaded
        } catch {
            print("Error loading photos: \(error)")
        }
    }
    
    func selectPhotoAtIndex(_ index: Int, selected isSelected: Bool) {
        //var photo = photos[index]
        photos[index].isSelected = isSelected
        //photos[index] = photo
        print("Photo at index \(index) is now \(photos[index].isSelected ? "selected" : "deselected")")
    }
    
    func showImageAtIndex(_ index: Int, _ completion: (() -> Void)? = nil) {
        currentIndex = switch index {
        case ..<0:
            photos.count - 1
        case photos.count:
            0
        default:
            index
        }
        
        let delayedLoader = Task {
            do {
                try await Task.sleep(nanoseconds: 500_000_000) // 2 seconds
                // Check if cancelled before doing work
                try Task.checkCancellation()
                
                await MainActor.run {
                    self.isImageLoading = true
                }
            } catch {
                print("Task was cancelled")
            }
        }
        
        gallery.loadImage(from: photos[index].asset) { [weak self] uiImage in
            self?.photo = self?.photos[index]
            self?.photo?.image = uiImage
            self?.showImage()
            delayedLoader.cancel()
            self?.isImageLoading = false
            completion?()
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
    
    func showNextImage(_ completion: (() -> Void)? = nil) {
        showImageAtIndex(currentIndex + 1, completion)
    }
    
    func showPreviousImage(_ completion: (() -> Void)? = nil) {
        showImageAtIndex(currentIndex - 1, completion)
    }
    
    func showGallery() {
        state = .loaded
        photo = nil
    }
}
