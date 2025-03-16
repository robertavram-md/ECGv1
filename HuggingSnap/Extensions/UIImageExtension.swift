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
        // We use a proper imageOrientation approach to avoid quality loss
        let rotatedImage = UIImage(cgImage: self.cgImage!, 
                                  scale: self.scale, 
                                  orientation: .right)
        
        // Create an autoreleased image to ensure proper orientation is applied
        UIGraphicsBeginImageContextWithOptions(
            CGSize(width: self.size.height, height: self.size.width),
            false, self.scale)
        rotatedImage.draw(in: CGRect(x: 0, y: 0, 
                                     width: self.size.height, 
                                     height: self.size.width))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }
    
    /// Creates a new version of the image with proper contrast for ECG readability
    func enhanceForECGDisplay() -> UIImage {
        // Create a CIImage from the UIImage
        guard let ciImage = CIImage(image: self) else { return self }
        
        // Create a filter chain to enhance the ECG
        let filters = ciImage
            // Increase contrast slightly
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.1,
                kCIInputBrightnessKey: 0.0,
                kCIInputSaturationKey: 0.0 // Remove color for better readability
            ])
            // Apply unsharp mask for better edge detection
            .applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 1.0,
                kCIInputIntensityKey: 0.5
            ])
        
        // Convert back to UIImage
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(filters, from: filters.extent) else {
            return self
        }
        
        return UIImage(cgImage: cgImage, scale: self.scale, orientation: self.imageOrientation)
    }
}