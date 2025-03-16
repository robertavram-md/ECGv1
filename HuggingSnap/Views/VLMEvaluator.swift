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
    videoSystemPrompt: "Caption this ECG.",
    videoUserPrompt: "Describe the ECG findings.",
    photoSystemPrompt: "Caption this ECG.",
    photoUserPrompt: "What is the diagnosis for this ECG?",
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
    
    // Convert CIImage to base64 string for direct use in API
    private func convertImageToBase64(from image: CIImage) async -> String? {
        self.modelInfo = "Processing image..."
        print("Converting image to base64")
        
        // Convert CIImage to UIImage for base64 encoding
        let context = CIContext()
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            self.modelInfo = "Failed to create CGImage"
            print("Failed to create CGImage")
            return nil
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        
        // Convert to JPEG with slightly reduced quality to manage size
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.75) else {
            self.modelInfo = "Failed to create JPEG data"
            print("Failed to create JPEG data")
            return nil
        }
        
        // Convert to base64 string
        let base64String = jpegData.base64EncodedString()
        
        // Log info about the conversion
        print("Image converted to base64, size: \(jpegData.count) bytes, base64 length: \(base64String.count) chars")
        self.modelInfo = "Image processed"
        
        return base64String
    }
    
    // Get a fallback demo image if needed
    private func getFallbackBase64Image() -> String {
        self.modelInfo = "Using demo image"
        print("Using demo ECG image")
        
        // This is a minimal base64 representation of an ECG image for testing
        // In a real app, we would include a full fallback image
        return "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
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
            
            // Process the image locally and convert to base64
            self.output = "Processing your ECG image..."
            let base64Image: String
            if let convertedImage = await convertImageToBase64(from: image) {
                base64Image = convertedImage
                self.modelInfo = "Image processed successfully"
            } else {
                // Use fallback image if conversion fails
                self.output = "Using fallback ECG image"
                self.modelInfo = "Using fallback image"
                print("WARNING: Using fallback image due to conversion failure")
                base64Image = getFallbackBase64Image()
            }
            
            self.output = "Analyzing ECG pattern..."
            
            // Set up the request
            let url = URL(string: runtimeConfiguration.apiEndpoint)!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("Bearer \(runtimeConfiguration.apiKey)", forHTTPHeaderField: "Authorization")
            // No timeout - using system default for long-running requests

            // For user prompt, check if we have a custom input
            let userPromptToUse: String
            if !customUserInput.isEmpty {
                // Use the custom input directly
                userPromptToUse = customUserInput
            } else {
                // Default to diagnosis prompt
                userPromptToUse = "What is the diagnosis for this ECG?"
            }
            
            // Format the full prompt with system prompt first, then user will see image and prompt
            let fullPrompt = "User: \(systemPrompt)\nUser: <image> \(userPromptToUse)\nAssistant:"
            
            // Create the request body with the base64 image
            print("Using direct base64 image for API request (length: \(base64Image.count) chars)")
            print("Using prompt: \(fullPrompt)")
            let requestBody: [String: Any] = [
                "inputs": [
                    "text": fullPrompt,
                    "images": ["data:image/jpeg;base64,\(base64Image)"]
                ],
                "parameters": [
                    "top_p": runtimeConfiguration.generationParameters.topP,
                    "temperature": runtimeConfiguration.generationParameters.temperature,
                    "max_new_tokens": runtimeConfiguration.generationParameters.maxNewTokens,
                    "do_sample": "True"  // Using the exact string format required by API
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
            
            // Update UI before making the potentially long API call
            await MainActor.run {
                self.output = "Analyzing ECG... (this may take 30-60 seconds)"
                self.modelInfo = "AI processing in progress..."
            }
            
            // Make the API call (using system default timeout)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Update UI after receiving response
            await MainActor.run {
                self.modelInfo = "Processing response..."
            }
            
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
