//
//  CloundAIServices.swift
//  AppIOS
//
//  Created by Alumno on 11/04/26.
//



import Foundation
import UIKit
import Network

final class CloudAIService: @unchecked Sendable {
    
    
    enum AIProvider: String {
        case openAI = "openai"
        case anthropic = "anthropic"
    }
    var provider: AIProvider = .openAI
    private let openAIBaseURL = "https://api.openai.com/v1/chat/completions"
    private let anthropicBaseURL = "https://api.anthropic.com/v1/messages"
    private let session: URLSession
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.guidevision.network.monitor")
    private(set) var isConnected: Bool = false
    private(set) var isWiFi: Bool = false
    
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
        
        setupNetworkMonitor()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    

    private func setupNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
            self?.isWiFi = path.usesInterfaceType(.wifi)
        }
        networkMonitor.start(queue: monitorQueue)
    }
    

    private func getAPIKey() -> String? {
        switch provider {
        case .openAI:
            return UserDefaults.standard.string(forKey: "openai_api_key")
        case .anthropic:
            return UserDefaults.standard.string(forKey: "anthropic_api_key")
        }
    }
    
   
    func setAPIKey(_ key: String, for provider: AIProvider) {
        switch provider {
        case .openAI:
            UserDefaults.standard.set(key, forKey: "openai_api_key")
        case .anthropic:
            UserDefaults.standard.set(key, forKey: "anthropic_api_key")
        }
    }
    

    func describeScene(imageData: Data) async throws -> String {
        guard isConnected else {
            throw CloudAIError.noConnection
        }
        
        guard let apiKey = getAPIKey() else {
            throw CloudAIError.noAPIKey
        }
        
        let base64Image = imageData.base64EncodedString()
        
        switch provider {
        case .openAI:
            return try await describeWithOpenAI(base64Image: base64Image, apiKey: apiKey)
        case .anthropic:
            return try await describeWithAnthropic(base64Image: base64Image, apiKey: apiKey)
        }
    }
    
    
    private func describeWithOpenAI(base64Image: String, apiKey: String) async throws -> String {
        var request = URLRequest(url: URL(string: openAIBaseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "system",
                    "content": "Eres un asistente visual para personas con discapacidad visual. Describe de forma clara y concisa en español lo que ves en la imagen. Enfócate en: objetos presentes, su posición relativa (izquierda, centro, derecha), distancia estimada, y cualquier texto visible. Sé breve y práctico."
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "Describe lo que ves en esta imagen. Menciona los objetos principales, su ubicación y distancia aproximada."
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 300
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CloudAIError.apiError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw CloudAIError.invalidResponse
        }
        
        return content
    }
    
    
    private func describeWithAnthropic(base64Image: String, apiKey: String) async throws -> String {
        var request = URLRequest(url: URL(string: anthropicBaseURL)!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 300,
            "system": "Eres un asistente visual para personas con discapacidad visual. Describe de forma clara y concisa en español lo que ves en la imagen. Enfócate en: objetos presentes, su posición relativa (izquierda, centro, derecha), distancia estimada, y cualquier texto visible. Sé breve y práctico.",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "Describe lo que ves en esta imagen. Menciona los objetos principales, su ubicación y distancia aproximada."
                        ]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CloudAIError.apiError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw CloudAIError.invalidResponse
        }
        
        return text
    }
}


enum CloudAIError: LocalizedError {
    case noConnection
    case noAPIKey
    case apiError(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No hay conexión a internet disponible."
        case .noAPIKey:
            return "No se ha configurado la API key. Ve a Ajustes para configurarla."
        case .apiError(let detail):
            return "Error de la API: \(detail)"
        case .invalidResponse:
            return "La respuesta de la API no es válida."
        }
    }
}
