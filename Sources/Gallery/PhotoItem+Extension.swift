//
//  PhotoItem+Extension.swift
//  Gallery
//
//  Created by Kevin LAUNAY.
//

import UIKit
import Photos

extension PhotoItem {
    /// Loads the full-resolution image asynchronously using the provided or default gallery service.
    /// - Parameter gallery: The gallery service to use (defaults to `Gallery.shared`).
    /// - Returns: The full-resolution `UIImage`.
    public func loadFullImage(gallery: any GalleryProtocol = Gallery.shared) async throws -> UIImage {
        if let image {
            return image
        }
        return try await gallery.loadImage(from: asset)
    }
}

extension Collection where Element == PhotoItem {
    /// Asynchronously loads full-resolution `UIImage`s for all items in the collection,
    /// preserving original order and falling back to thumbnails if loading fails.
    /// - Parameter gallery: The gallery service to use (defaults to `Gallery.shared`).
    /// - Returns: An array of loaded `UIImage`s in the order of the collection.
    public func loadFullImages(gallery: any GalleryProtocol = Gallery.shared) async -> [UIImage] {
        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, item) in self.enumerated() {
                group.addTask {
                    if let existing = item.image {
                        return (index, existing)
                    }
                    let loaded = try? await gallery.loadImage(from: item.asset)
                    return (index, loaded ?? item.thumb)
                }
            }

            var orderedResults = [(Int, UIImage?)]()
            for await result in group {
                orderedResults.append(result)
            }
            orderedResults.sort { $0.0 < $1.0 }
            return orderedResults.compactMap { $0.1 }
        }
    }
}
