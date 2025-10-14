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
    @State var model: GalleryModel
    @Binding var selectedPhotos: [PhotoItem]
    
    public init(bundle: Bundle? = nil, selectedPhotos: Binding<[PhotoItem]> = .constant([])) {
        self._selectedPhotos = selectedPhotos
        let resolvedBundle = bundle ?? Bundle.module
        self.bundle = resolvedBundle
        self.model = GalleryModel()
    }

    init(model: GalleryModel) {
        self.model = model
        self.bundle = .module
        self._selectedPhotos = .constant([])
    }
    
    public var body: some View {
            ZStack {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100,maximum: 200), spacing: 8, alignment: .top)], spacing: 8) {
                        ForEach(Array(model.photos.enumerated()), id: \.element ) { index, photo in
                            ThumbnailView(isSelected: photo.isSelected, isLoading: photo.isLoading ,photo: photo, onTap: { isSelected in
                                Task {
                                    await model.selectPhotoAtIndex(index, selected: isSelected)
                                }
                                
                            }, onLongPress: {
                                Task {
                                    await model.showImageAtIndex(index)
                                }
                            })
                            .animation(.default, value: model.photos[index].isSelected)
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                }

                switch model.state {
                case .loading:
                    ProgressView("Loading Photos...")
                        .task {
                            await model.loadPhotos()
                        }

                case .error(let error):
                    Text("Error loading photos: \(error.localizedDescription)")
                        .foregroundColor(.red)
                case .displaying:
                    if case let .displaying(isLoading) = model.state {
                        ImageViewer(model: model)
                            .transition(.opacity.combined(with: .scale))
                            .ignoresSafeArea()
                            .overlay {
                                if isLoading {
                                    ProgressView("Loading Image...")
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.5)
                                }
                            }
                            
                    }
                case .browsing:
                    EmptyView()
                }
                
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
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



#Preview {
    GalleryView(model: GalleryModel())
}
