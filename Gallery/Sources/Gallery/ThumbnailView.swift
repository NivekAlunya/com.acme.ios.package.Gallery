//
//  ThumbnailView.swift
//  Gallery
//
//  Created by Kevin LAUNAY on 12/09/2025.
//
import SwiftUI

struct ThumbnailView: View {
    let isSelected: Bool
    let isLoading: Bool
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
            .overlay {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                        .background(Color.black.opacity(0.5).clipShape(RoundedRectangle(cornerRadius: 12)))
                }
            }
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
