import Foundation

enum UrlFetchStatus: Equatable {
    case completed
    case failed(Error)
    case pending
    case rateLimited
    
    static func == (lhs: UrlFetchStatus, rhs: UrlFetchStatus) -> Bool {
        switch (lhs, rhs) {
        case (.completed, .completed),
            (.pending, .pending),
            (.rateLimited, .rateLimited):
            return true
        case (.failed(let leftError), .failed(let rightError)):
            return (leftError as NSError) == (rightError as NSError)
        default:
            return false
        }
    }
}

struct UrlResponse: Codable {
    let url: String?
}

class RemoteUrlProvider: ObservableObject {
    static let shared = RemoteUrlProvider()
    
    private let remoteServerUrl = "https://url-server-choice-journal-production.up.railway.app/"
    
    private init() {}
    
    func fetchRemoteUrl() async -> (url: String?, state: UrlFetchStatus) {
        guard let url = URL(string: remoteServerUrl) else {
            let error = NSError(
                domain: "RemoteUrlProvider",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid configuration URL"]
            )
            return (nil, .failed(error))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = NSError(
                    domain: "RemoteUrlProvider",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"]
                )
                return (nil, .failed(error))
            }
            
            // Handle rate limiting (429 status code)
            if httpResponse.statusCode == 429 {
                return (nil, .rateLimited)
            }
            
            // Handle other errors
            guard (200...299).contains(httpResponse.statusCode) else {
                let error = NSError(
                    domain: "RemoteUrlProvider",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP error: \(httpResponse.statusCode)"]
                )
                return (nil, .failed(error))
            }
            
            // Parse JSON response
            let decoder = JSONDecoder()
            let urlResponse = try decoder.decode(UrlResponse.self, from: data)
            
            if let urlString = urlResponse.url, !urlString.isEmpty {
                return (urlString, .completed)
            } else {
                return (nil, .completed)
            }
            
        } catch let error as DecodingError {
            let decodingError = NSError(
                domain: "RemoteUrlProvider",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to decode JSON: \(error.localizedDescription)"]
            )
            return (nil, .failed(decodingError))
        } catch {
            return (nil, .failed(error))
        }
    }
}
