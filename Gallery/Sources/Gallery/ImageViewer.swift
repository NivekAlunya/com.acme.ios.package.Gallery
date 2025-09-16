//
//  ImageViewer.swift
//  Gallery
//
//  Created by Kevin LAUNAY on 05/09/2025.
//

import SwiftUI

struct ImageViewer: View {
    let model: GalleryModel
    @State private var dragOffset = CGFloat(0)
    @State private var viewSize: CGSize = .zero
    @State private var isDragging = false
    var body: some View {
        ZStack {
            if let image = model.photo?.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .draggable(
                        offset: $dragOffset
                        , threshold: 100
                        , onSwipeLeft: {
                            withAnimation {
                                dragOffset = -viewSize.width
                            } completion: {
                                dragOffset = viewSize.width
                                withAnimation {
                                    Task {
                                        await model.showNextImage()
                                        withAnimation {
                                            dragOffset = 0
                                        }
                                    }
                                }
                            }
                        }
                        , onSwipeRight: {
                            withAnimation {
                                dragOffset = viewSize.width
                            } completion: {
                                dragOffset = -viewSize.width
                                withAnimation {
                                    Task {
                                        await model.showPreviousImage()
                                        withAnimation {
                                            dragOffset = 0
                                        }

                                    }
                                }
                            }
                        })
                    .overlay {
                        if model.photo?.isLoading == true {
                            ProgressView("Loading Image...")
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                        }
                    }
            } else {
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial)
        .onGeometryChange(for: CGSize.self) { proxy in
            return proxy.size
        } action: { newSize in
            viewSize = newSize
            print("ImageViewer newSize: \(newSize)")
        }
        .onTapGesture {
            withAnimation {
                model.showGallery()
            }
        }

    }
}
