//
//  VLMEvaluator.swift
//  HuggingSnap
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
    videoSystemPrompt: "Focus only on describing the key dramatic action or notable event occurring in this video segment. Skip general context or scene-setting details unless they are crucial to understanding the main action.",
    videoUserPrompt: "What is the main action or notable event happening in this segment? Describe it in one brief sentence.",
    photoSystemPrompt: "You are an image understanding model capable of describing the salient features of any image.",
    photoUserPrompt: "Describe this image.",
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
    
    // Get image URL for API
    private func uploadImageAndGetURL(from image: CIImage) async -> String? {
        // For demo purposes, we're using a fixed URL that works with the API
        self.modelInfo = "Using ECG demo image"
        
        // Using the ECG image URL you provided in the API example
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
        
        do {
            // Determine which prompt to use
            let systemPrompt = videoURL != nil ? runtimeConfiguration.videoSystemPrompt : runtimeConfiguration.photoSystemPrompt
            let userPrompt = customUserInput.isEmpty ? 
                (videoURL != nil ? runtimeConfiguration.videoUserPrompt : runtimeConfiguration.photoUserPrompt) : 
                customUserInput
            
            // Get a remote URL for the image
            guard let imageUrl = await uploadImageAndGetURL(from: image) else {
                self.output = "Failed to process image"
                running = false
                return
            }
            
            // Set up the request
            let url = URL(string: runtimeConfiguration.apiEndpoint)!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("Bearer \(runtimeConfiguration.apiKey)", forHTTPHeaderField: "Authorization")
            
            // Create the prompt with system and user prompts
            let fullPrompt = "User: \(userPrompt)<image>\nAssistant:"
            
            // Create the request body - matching exactly the format you provided
            let requestBody: [String: Any] = [
                "inputs": [
                    "text": "User: Can you describe this ECG image?!<image>\nAssistant:",
                    "images": [imageUrl]
                ],
                "parameters": [
                    "top_p": 0.9,
                    "temperature": 0.7,
                    "max_new_tokens": 512,
                    "do_sample": "True"
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
                        }
                    } else if let outputArray = responseJson["outputs"] as? [[String: Any]],
                              let firstOutput = outputArray.first,
                              let text = firstOutput["text"] as? String {
                        // Alternative format
                        print("Found outputs/text: \(text)")
                        let cleanedText = extractAssistantResponse(from: text)
                        await MainActor.run {
                            self.output = cleanedText
                        }
                    } else if let responseArray = responseJson as? [Any],
                             let firstItem = responseArray.first as? [String: Any],
                             let text = firstItem["generated_text"] as? String {
                        // Array format - this is what we're getting
                        print("Found array with generated_text: \(text)")
                        let cleanedText = extractAssistantResponse(from: text)
                        await MainActor.run {
                            self.output = cleanedText
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
