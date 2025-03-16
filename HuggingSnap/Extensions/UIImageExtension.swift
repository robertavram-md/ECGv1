//
//  UIImageExtension.swift
//  SnapECG
//
//  Created on 3/16/24.
//

import UIKit

extension UIImage {
    /// Ensures ECG images are in horizontal format (width > height)
    func ensureHorizontalOrientation() -> UIImage {
        // If width is already greater than height, return the image as is
        if self.size.width > self.size.height {
            return self
        }
        
        // Otherwise, rotate the image to make it horizontal
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: self.size.height, height: self.size.width))
        return renderer.image { ctx in
            ctx.cgContext.translateBy(x: 0, y: self.size.height)
            ctx.cgContext.rotate(by: -.pi/2)
            self.draw(at: .zero)
        }
    }
}