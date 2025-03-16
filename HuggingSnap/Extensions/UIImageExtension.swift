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
        print("Original image size: \(self.size.width) × \(self.size.height)")
        
        // If width is already greater than height, return the image as is
        if self.size.width > self.size.height {
            print("Image is already horizontal")
            return self
        }
        
        print("Rotating vertical image to horizontal orientation")
        
        // Step 1: Create a rotated image with correct orientation
        // For vertical images, we need to rotate 90 degrees clockwise
        let targetSize = CGSize(width: self.size.height, height: self.size.width)
        
        // Create a bitmap context with the target size
        UIGraphicsBeginImageContextWithOptions(targetSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!
        
        // Move the origin to the middle of the context
        context.translateBy(x: targetSize.width / 2, y: targetSize.height / 2)
        
        // Rotate 90 degrees clockwise (negative pi/2)
        context.rotate(by: -CGFloat.pi / 2)
        
        // Draw the original image centered
        let rect = CGRect(
            x: -self.size.width / 2,
            y: -self.size.height / 2,
            width: self.size.width,
            height: self.size.height
        )
        
        // Draw the image
        self.draw(in: rect)
        
        // Get the rotated image from the context
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        print("Rotated image size: \(rotatedImage.size.width) × \(rotatedImage.size.height)")
        return rotatedImage
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