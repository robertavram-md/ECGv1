// APIConfig.template.swift
// This is a template for APIConfig.swift for SnapECG
// IMPORTANT: Copy this file to APIConfig.swift and fill in your actual API keys
// The actual APIConfig.swift file is excluded from git to keep credentials secure

import Foundation

struct APIConfig {
    // API endpoint and key
    static let huggingFaceAPIEndpoint = "https://q61a3zug772ocqe0.eastus.azure.endpoints.huggingface.cloud"
    static let huggingFaceAPIKey = "YOUR_API_KEY_HERE" // Default is already set in the real file
    
    // Used for checking if config is valid
    static var isConfigured: Bool {
        return !huggingFaceAPIKey.isEmpty && huggingFaceAPIKey != "YOUR_API_KEY_HERE"
    }
}