//
//  Draggable.swift
//  Gallery
//
//  Created by Kevin LAUNAY on 04/09/2025.
//

import SwiftUI

struct Draggable: ViewModifier {
    @Binding var offset: CGFloat
    let threshold: CGFloat
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void
    @State private var opacity = 1.0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(opacity)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { gesture in
                        print("Drag changed: \(gesture.translation.width)")
                        withAnimation {
                            offset = gesture.translation.width
                            opacity = (1.0 - min(abs(offset) / (2 * threshold), 0.5))
                        }
                    }
                    .onEnded { gesture in
                        if offset > threshold {
                            onSwipeRight()
                        } else if offset < -threshold {
                            onSwipeLeft()
                        } else {
                            withAnimation {
                                offset = 0
                            }
                        }
                    }
            )
            .onChange(of: offset) { oldValue, newValue in
                if newValue == 0 {
                    withAnimation {
                        opacity = 1.0
                    }
                }
            }
    }
}

extension View {
    func draggable(offset: Binding<CGFloat>, threshold: CGFloat = 100, onSwipeLeft: @escaping () -> Void, onSwipeRight: @escaping () -> Void) -> some View {
        self.modifier(Draggable(offset: offset, threshold: threshold, onSwipeLeft: onSwipeLeft, onSwipeRight: onSwipeRight))
    }
}
