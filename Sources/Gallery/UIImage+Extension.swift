//
//  File.swift
//  Gallery
//
//  Created by Kevin LAUNAY on 05/09/2025.
//

import UIKit

extension UIImage {
    static func whitePlaceholderWithBorder(
        size: CGSize = CGSize(width: 100, height: 100),
        borderColor: UIColor = .lightGray,
        borderWidth: CGFloat = 1
    ) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            // Fill white background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add border
            borderColor.setStroke()
            let borderRect = CGRect(origin: .zero, size: size).insetBy(dx: borderWidth/2, dy: borderWidth/2)
            context.stroke(borderRect)
        }
    }
}
