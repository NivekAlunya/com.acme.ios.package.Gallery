//
//  GalleryView.swift
//  Gallery
//
//  Created by Kevin LAUNAY on 03/09/2025.
//

import SwiftUI
import UIKit

extension EnvironmentValues {
    @Entry var bundle: Bundle = Bundle.module
}

public struct GalleryView: View {
    private let bundle: Bundle
    @StateObject private var model: GalleryModel
    @Binding var selectedPhotos: [PhotoItem]
    
    public init(bundle: Bundle? = nil, selectedPhotos: Binding<[PhotoItem]> = .constant([])) {
        self._selectedPhotos = selectedPhotos
        let resolvedBundle = bundle ?? Bundle.module
        self.bundle = resolvedBundle
        _model = StateObject(wrappedValue: GalleryModel())
    }

    init(model: GalleryModel) {
        _model = StateObject(wrappedValue: model)
        self.bundle = .module
        self._selectedPhotos = .constant([])
    }
    
    public var body: some View {
            ZStack {
                switch model.state {
                case .loading:
                    ProgressView("Loading Photos...")
                case .error(let error):
                    Text("Error loading photos: \(error.localizedDescription)")
                        .foregroundColor(.red)
                case .loaded, .displaying:
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100,maximum: 200), spacing: 8, alignment: .top)], spacing: 8) {
                            ForEach(Array(model.photos.enumerated()), id: \.element ) { index, photo in
                                ThumbnailView(isSelected: photo.isSelected ,photo: photo, onTap: {
                                    Task {
                                        await model.showImageAtIndex(index)
                                    }
                                }, onLongPress: { isSelected in
                                    model.selectPhotoAtIndex(index, selected: isSelected)
                                })
                                .animation(.default, value: model.photos[index].isSelected)
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                    }
                    if model.state == .displaying {
                        ImageViewer(model: model)
                            .transition(.opacity.combined(with: .scale))
                            .ignoresSafeArea()
                    }
                }
                
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await model.loadPhotos()
        }
        .environment(\.bundle, bundle)
        .onChange(of: model.photos) { newPhotos in
            selectedPhotos = newPhotos.filter { $0.isSelected }
            print("GalleryView: selectedPhotos count: \(selectedPhotos.count)")
        }
        .onChange(of: selectedPhotos) { newPhotos in
            print("GalleryView: selectedPhotos changed externally, count: \(newPhotos.count)")
            model.syncPhotos(selectedPhotos: newPhotos)
        }
    }
}

struct ThumbnailView: View {
    let isSelected: Bool
    let photo: PhotoItem
    let onTap: () -> Void
    let onLongPress: (Bool) -> Void
    
    var body: some View {
        
        Image(uiImage: photo.thumb)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.accentColor)
                        .padding(6)
                }
            }
            .onTapGesture(perform: onTap)
            .onLongPressGesture {
                onLongPress(!isSelected)
                print("ThumbnailView: photo id: \(photo.id), isSelected: \(isSelected)")
            }
            .scaleEffect(isSelected ? 0.95 : 1.0)
    }
}

#Preview {
    GalleryView(model: GalleryModel())
}
