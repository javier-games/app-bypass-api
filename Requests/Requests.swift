//
//  requests.swift
//  Requests
//
//  Created by Javier García on 2023/05/24.
//

import Foundation

public enum HTTPMethod:String, CaseIterable, Identifiable, Codable {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    public var id: String { self.rawValue }
}

public enum BodyType:String, CaseIterable, Identifiable, Codable {
    case NONE = "No Body"
    case FORM_DATA = "Form Data"
    case JSON = "JSON"
    public var id: String { self.rawValue }
}

public struct KeyValuePair: Codable {
    public var key: String
    public var value: String
    
    public init() {
        self.key = ""
        self.value = ""
    }
    
    public init(key: String, value: String){
        self.key = key
        self.value = value
    }
    
}

public struct Request: Codable {
    public let id: UUID
    public var name: String
    public var url: String
    public var httpMethod: HTTPMethod
    public var urlParams: [KeyValuePair]
    public var headers: [KeyValuePair]
    public var bodyType: BodyType
    public var formData: [KeyValuePair]
    public var rawBody: String
    
    public init(
        id: UUID = UUID(),
        name: String,
        url: String,
        httpMethod: HTTPMethod,
        urlParams: [KeyValuePair] = [],
        headers: [KeyValuePair] = [],
        bodyType: BodyType = BodyType.FORM_DATA,
        formData: [KeyValuePair] = [],
        rawBody: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.httpMethod = httpMethod
        self.urlParams = urlParams
        self.headers = headers
        self.bodyType = bodyType
        self.formData = formData
        self.rawBody = rawBody
    }
    
    public func sendRequest() async throws -> String {
        return try await withCheckedThrowingContinuation {
            continuation in
            
            // Prepare the URL
            guard let url = URL(string: self.url) else {
                continuation.resume(throwing: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
                return
            }
            
            // Prepare the request
            var request = URLRequest(url: url)
            request.httpMethod = self.httpMethod.rawValue
            
            // Add headers to the request
            for keyValuePair in self.headers {
                request.addValue(keyValuePair.value, forHTTPHeaderField: keyValuePair.key)
            }
            
            // Add body
            switch self.bodyType {
                
            case .FORM_DATA:
                
                // Create the boundary and set the content type
                let boundary = "Boundary-\(UUID().uuidString)"
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                
                // Prepare the body
                var body = ""
                for keyValuePair in self.formData {
                    body += "--\(boundary)\r\n"
                    body += "Content-Disposition: form-data; name=\"\(keyValuePair.key)\"\r\n\r\n"
                    body += "\(keyValuePair.value)\r\n"
                }
                body += "--\(boundary)--\r\n"
                
                // Set the request body
                request.httpBody = body.data(using: .utf8)
                
            case .JSON:
                
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let jsonData = self.rawBody.data(using: .utf8) {
                    request.httpBody = jsonData
                } else {
                    print("Failed to convert JSON string to data.")
                }
                
            case .NONE:
                print("No body data required.")
            }
            
            // Create a URLSession and send the request
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data {
                    if let str = String(data: data, encoding: .utf8) {
                        continuation.resume(returning: str)
                    } else {
                        continuation.resume(throwing: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Data could not be converted to string"]))
                    }
                } else {
                    continuation.resume(throwing: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                }
            }
            
            // Start the data task
            task.resume()
            
        }
    }
}

public class RequestsData: ObservableObject {
    
    @Published public var requests: [Request] {
        didSet {
            saveRequests()
        }
    }
    
    public init() {
        let sharedUserDefaults = UserDefaults(suiteName: "group.games.javier.bypass-api")
        if let savedRequests = sharedUserDefaults?.data(forKey: "SavedRequests") {
            let decoder = JSONDecoder()
            if let loadedRequests = try? decoder.decode([Request].self, from: savedRequests) {
                self.requests = loadedRequests
            } else {
                self.requests = []
            }
        } else {
            self.requests = []
        }
    }
    
    func saveRequests() {
        let sharedUserDefaults = UserDefaults(suiteName: "group.games.javier.bypass-api")
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(requests) {
            sharedUserDefaults?.set(encoded, forKey: "SavedRequests")
        }
    }
    
    func loadRequests() -> [Request] {
        let sharedUserDefaults = UserDefaults(suiteName: "group.games.javier.bypass-api")
        if let savedRequests = sharedUserDefaults?.data(forKey: "SavedRequests") {
            let decoder = JSONDecoder()
            if let loadedRequests = try? decoder.decode([Request].self, from: savedRequests) {
                return loadedRequests
            }
        }
        return []
    }
}
