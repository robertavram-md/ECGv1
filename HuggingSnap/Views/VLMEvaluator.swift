//
//  VLMEvaluator.swift
//  SnapECG
//
//  Created by Cyril Zakka on 2/14/25.
//

import SwiftUI
import Foundation
import UIKit // For UIImage
// We don't need to import APIConfig since it's in the same module

// Runtime configuration for API access

struct SnapECGModelConfiguration: Codable, Sendable {
    let videoSystemPrompt: String
    let videoUserPrompt: String
    let photoSystemPrompt: String
    let photoUserPrompt: String
    let generationParameters: GenerationParameters
    
    // API configuration
    let apiEndpoint: String
    let apiKey: String

    struct GenerationParameters: Codable, Sendable {
        let temperature: Float
        let topP: Float
        let maxNewTokens: Int
        let doSample: Bool
    }
}

// Default configuration
fileprivate var runtimeConfiguration: SnapECGModelConfiguration = SnapECGModelConfiguration(
    videoSystemPrompt: "You are an ECG interpretation assistant. Analyze ECG patterns for abnormalities.",
    videoUserPrompt: "Describe the ECG findings and potential diagnoses.",
    photoSystemPrompt: "You are an ECG interpretation assistant. You analyze ECG images and provide detailed findings including rhythm, intervals, and potential abnormalities.",
    photoUserPrompt: "Analyze this ECG image. Describe the rhythm, rate, intervals, and any abnormalities you observe.",
    generationParameters: SnapECGModelConfiguration.GenerationParameters(
        temperature: 0.7, 
        topP: 0.9,
        maxNewTokens: 512,
        doSample: true
    ),
    apiEndpoint: APIConfig.huggingFaceAPIEndpoint,
    apiKey: APIConfig.huggingFaceAPIKey
)

@Observable
@MainActor
class VLMEvaluator {

    var running = false
    var customUserInput = ""
    var output = ""
    var modelInfo = "Ready to use"
    var stat = ""
    
    // Load function that validates the API configuration
    func load() async throws -> Bool {
        // Check if API key is properly configured
        if APIConfig.isConfigured {
            self.modelInfo = "API Ready"
        } else {
            self.modelInfo = "API Key Not Configured"
            print("WARNING: API Key not configured. Please set a valid API key in APIConfig.swift")
        }
        return true
    }
    
    // Convert CIImage to base64 string for API
    private func ciImageToBase64(image: CIImage) -> String? {
        let context = CIContext()
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return nil
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        guard let imageData = uiImage.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        
        return imageData.base64EncodedString()
    }
    
    // Upload image to ImgBB and get URL for API
    private func uploadImageAndGetURL(from image: CIImage) async -> String? {
        self.modelInfo = "Uploading image..."
        print("Starting image upload process")
        
        // Convert CIImage to UIImage for upload
        let context = CIContext()
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            self.modelInfo = "Failed to create CGImage"
            print("Failed to create CGImage")
            return nil
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.85) else {
            self.modelInfo = "Failed to create JPEG data"
            print("Failed to create JPEG data")
            return nil
        }
        
        // Create base64 string
        let base64Image = jpegData.base64EncodedString()
        print("Image converted to base64, length: \(base64Image.count) chars")
        
        // Upload to ImgBB
        let imgbbApiKey = "c1e8de9b2cdd31d9f7e14dea1972d7b2" // Free ImgBB API key
        let imgbbUrl = URL(string: "https://api.imgbb.com/1/upload")!
        
        var request = URLRequest(url: imgbbUrl)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Create form data using URLComponents for proper encoding
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "key", value: imgbbApiKey),
            URLQueryItem(name: "image", value: base64Image)
        ]
        
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        
        print("Sending request to ImgBB...")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.modelInfo = "Upload failed: Not an HTTP response"
                print("Upload failed: Not an HTTP response")
                return getDemoImageUrl()
            }
            
            print("ImgBB HTTP status code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                self.modelInfo = "Upload failed: HTTP \(httpResponse.statusCode)"
                
                // Try to get error message
                if let responseString = String(data: data, encoding: .utf8) {
                    print("ImgBB error response: \(responseString)")
                }
                
                return getDemoImageUrl()
            }
            
            // Parse the JSON response from ImgBB
            guard let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                self.modelInfo = "Failed to parse JSON response"
                print("Failed to parse JSON response")
                return getDemoImageUrl()
            }
            
            // Debug the entire response
            print("ImgBB JSON response: \(jsonObject)")
            
            // Check if upload was successful
            guard let success = jsonObject["success"] as? Bool, success == true else {
                self.modelInfo = "Upload not successful"
                print("Upload not successful according to JSON response")
                return getDemoImageUrl()
            }
            
            // Extract data section
            guard let dataDict = jsonObject["data"] as? [String: Any] else {
                self.modelInfo = "No data in response"
                print("No data dictionary in response")
                return getDemoImageUrl()
            }
            
            // Try different possible URL fields
            if let displayUrl = dataDict["display_url"] as? String {
                print("Image uploaded successfully: \(displayUrl)")
                self.modelInfo = "Image uploaded ✓"
                return displayUrl
            } else if let url = dataDict["url"] as? String {
                print("Image uploaded successfully: \(url)")
                self.modelInfo = "Image uploaded ✓"
                return url
            } else if let imageUrl = dataDict["image"] as? [String: Any], let url = imageUrl["url"] as? String {
                print("Image uploaded successfully: \(url)")
                self.modelInfo = "Image uploaded ✓"
                return url
            } else {
                self.modelInfo = "No URL found in response"
                print("No URL found in ImgBB response")
                return getDemoImageUrl()
            }
        } catch {
            self.modelInfo = "Upload error: \(error.localizedDescription)"
            print("Image upload error: \(error)")
            return getDemoImageUrl()
        }
    }
    
    // Get demo image URL as fallback
    private func getDemoImageUrl() -> String {
        self.modelInfo = "Using demo image"
        print("Using demo image instead")
        return "https://i.ibb.co/DFPXpBs/Image-2025-03-14-at-10-56-PM.jpg"
    }
    
    // Generate using the API
    func generate(image: CIImage?, videoURL: URL?) async {
        guard !running else { return }
        
        // Check if API key is configured
        guard APIConfig.isConfigured else {
            self.output = "ERROR: API Key not configured. Please set your API key in APIConfig.swift"
            return
        }
        
        running = true
        self.output = ""
        
        // Ensure we have an image to process
        guard let image = image else {
            self.output = "No image provided"
            running = false
            return
        }
        
        // Show initial processing message
        self.output = "Processing your ECG image..."
        
        do {
            // Determine which prompt to use
            let systemPrompt = videoURL != nil ? runtimeConfiguration.videoSystemPrompt : runtimeConfiguration.photoSystemPrompt
            let userPrompt = customUserInput.isEmpty ? 
                (videoURL != nil ? runtimeConfiguration.videoUserPrompt : runtimeConfiguration.photoUserPrompt) : 
                customUserInput
            
            // Get a remote URL for the image by uploading to ImgBB
            self.output = "Uploading your ECG image for analysis..."
            guard let imageUrl = await uploadImageAndGetURL(from: image) else {
                self.output = "Failed to upload image for analysis"
                running = false
                return
            }
            
            self.output = "Analyzing ECG pattern..."
            
            // Set up the request
            let url = URL(string: runtimeConfiguration.apiEndpoint)!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("Bearer \(runtimeConfiguration.apiKey)", forHTTPHeaderField: "Authorization")
            
            // Create the prompt with system and user prompts
            let fullPrompt = "User: \(userPrompt)<image>\nAssistant:"
            
            // Create the request body with ECG-specific prompt and uploaded image URL
            print("Using image URL for API request: \(imageUrl)")
            let requestBody: [String: Any] = [
                "inputs": [
                    "text": fullPrompt,
                    "images": [imageUrl]
                ],
                "parameters": [
                    "top_p": runtimeConfiguration.generationParameters.topP,
                    "temperature": runtimeConfiguration.generationParameters.temperature,
                    "max_new_tokens": runtimeConfiguration.generationParameters.maxNewTokens,
                    "do_sample": String(runtimeConfiguration.generationParameters.doSample)
                ]
            ]
            
            // Print request details for debugging
            print("API Request URL: \(runtimeConfiguration.apiEndpoint)")
            print("API Request Body: \(requestBody)")
            
            // Convert the request body to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            // Log the actual JSON being sent
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("JSON being sent: \(jsonString)")
            }
            
            // Make the API call
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Not an HTTP response")
                await MainActor.run {
                    self.output = "Error: Not an HTTP response"
                }
                running = false
                return
            }
            
            print("HTTP Status Code: \(httpResponse.statusCode)")
            
            // Check if we got a successful response
            guard httpResponse.statusCode == 200 else {
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                print("HTTP Error \(httpResponse.statusCode): \(responseString)")
                
                await MainActor.run {
                    self.output = "API Error (\(httpResponse.statusCode)): \(responseString)"
                }
                running = false
                return
            }
            
            // Process the response - with detailed debugging
            let responseString = String(data: data, encoding: .utf8) ?? "No response text"
            print("API Response: \(responseString)")
            
            // Always show raw response for debugging
            await MainActor.run {
                self.output = "Raw response: \(responseString)"
            }
            
            // Function to extract just the assistant's response
            func extractAssistantResponse(from fullText: String) -> String {
                if let range = fullText.range(of: "Assistant:") {
                    return String(fullText[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return fullText // Return original if "Assistant:" not found
            }
            
            // Try to parse as JSON
            do {
                // First check if it's an array (based on the response you shared)
                if let responseArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let firstItem = responseArray.first,
                   let generatedText = firstItem["generated_text"] as? String {
                    
                    print("Found array response format: \(generatedText)")
                    let cleanedText = extractAssistantResponse(from: generatedText)
                    await MainActor.run {
                        self.output = cleanedText
                        self.modelInfo = "ECG analysis complete"
                    }
                }
                // Then check standard object format
                else if let responseJson = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("JSON parsed: \(responseJson)")
                    
                    // Handle various response formats
                    
                    if let generatedText = responseJson["generated_text"] as? String {
                        // Standard Hugging Face format
                        print("Found generated_text: \(generatedText)")
                        let cleanedText = extractAssistantResponse(from: generatedText)
                        await MainActor.run {
                            self.output = cleanedText
                            self.modelInfo = "ECG analysis complete"
                        }
                    } else if let outputArray = responseJson["outputs"] as? [[String: Any]],
                              let firstOutput = outputArray.first,
                              let text = firstOutput["text"] as? String {
                        // Alternative format
                        print("Found outputs/text: \(text)")
                        let cleanedText = extractAssistantResponse(from: text)
                        await MainActor.run {
                            self.output = cleanedText
                            self.modelInfo = "ECG analysis complete"
                        }
                    } else if let responseArray = responseJson as? [Any],
                             let firstItem = responseArray.first as? [String: Any],
                             let text = firstItem["generated_text"] as? String {
                        // Array format - this is what we're getting
                        print("Found array with generated_text: \(text)")
                        let cleanedText = extractAssistantResponse(from: text)
                        await MainActor.run {
                            self.output = cleanedText
                            self.modelInfo = "ECG analysis complete"
                        }
                    } else {
                        // JSON found but not in expected format
                        print("JSON in unexpected format")
                        // Keep the raw response display
                    }
                }
            } catch {
                print("JSON parsing error: \(error)")
                // Raw response is already displayed
            }
            
        } catch {
            await MainActor.run {
                self.output = "Error: \(error.localizedDescription)"
            }
        }
        
        running = false
    }
}
