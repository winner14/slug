import Foundation
import AppKit

class ScreenshotNamer {

    // MARK: - Public

    func rename(url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let settings = AppSettings.shared

        guard !settings.apiKey.isEmpty else {
            completion(.failure(NamingError.noAPIKey))
            return
        }

        guard !settings.isOverFreeLimit else {
            completion(.failure(NamingError.freeLimitReached))
            return
        }

        guard let imageData = loadImage(at: url) else {
            completion(.failure(NamingError.imageLoadFailed))
            return
        }

        callGeminiVision(imageData: imageData) { [weak self] result in
            switch result {
            case .success(let slugName):
                do {
                    let newURL = try self?.renameFile(from: url, to: slugName) ?? url
                    AppSettings.shared.incrementRenameCount()
                    completion(.success(newURL))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Image Loading

    private func loadImage(at url: URL) -> Data? {
        guard let image = NSImage(contentsOf: url),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }

        // Resize if large to reduce API cost
        let maxDimension: CGFloat = 1568
        let size = image.size
        if size.width > maxDimension || size.height > maxDimension {
            let scale = maxDimension / max(size.width, size.height)
            let newSize = NSSize(width: size.width * scale, height: size.height * scale)
            let resized = NSImage(size: newSize)
            resized.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: newSize))
            resized.unlockFocus()
            if let resizedTiff = resized.tiffRepresentation,
               let resizedBitmap = NSBitmapImageRep(data: resizedTiff) {
                return resizedBitmap.representation(using: .png, properties: [:])
            }
        }

        return bitmap.representation(using: .png, properties: [:])
    }

    // MARK: - Gemini Vision API

    private func callGeminiVision(imageData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        let apiKey = AppSettings.shared.apiKey
        let base64Image = imageData.base64EncodedString()

        let prompt = """
        Give this screenshot a short, descriptive filename.
        Rules:
        - lowercase letters, numbers, hyphens only
        - 3–6 words max
        - describe what's shown (app, content, purpose)
        - no extension, no quotes
        - examples: figma-login-error, stripe-invoice-march, github-pr-review, slack-standup-thread
        Reply with ONLY the filename, nothing else.
        """

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "inline_data": [
                                "mime_type": "image/png",
                                "data": base64Image
                            ]
                        ],
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "maxOutputTokens": 500,
                "temperature": 0.2,
                "thinkingConfig": [
                    "thinkingBudget": 0
                ]
            ]
        ]

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"

        guard let url = URL(string: urlString),
              let body = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(NamingError.requestFailed))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 30

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NamingError.emptyResponse))
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                if let errorObj = json?["error"] as? [String: Any],
                   let message = errorObj["message"] as? String {
                    completion(.failure(NamingError.apiError(message)))
                    return
                }

                // Gemini response: candidates[0].content.parts[0].text
                guard let candidates = json?["candidates"] as? [[String: Any]],
                      let first = candidates.first,
                      let content = first["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]],
                      let part = parts.first,
                      let text = part["text"] as? String,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    // Log raw response for debugging
                    if let raw = String(data: data, encoding: .utf8) {
                        print("[Namer] Raw API response: \(raw)")
                    }
                    completion(.failure(NamingError.parseError))
                    return
                }

                let slug = self.sanitizeSlug(text.trimmingCharacters(in: .whitespacesAndNewlines))
                DispatchQueue.main.async {
                    completion(.success(slug))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - File Rename

    private func renameFile(from url: URL, to slug: String) throws -> URL {
        let folder = url.deletingLastPathComponent()
        var newURL = folder.appendingPathComponent(slug).appendingPathExtension("png")

        // Avoid collisions
        var counter = 2
        while FileManager.default.fileExists(atPath: newURL.path) {
            newURL = folder.appendingPathComponent("\(slug)-\(counter)").appendingPathExtension("png")
            counter += 1
        }

        try FileManager.default.moveItem(at: url, to: newURL)
        return newURL
    }

    // MARK: - Slug Sanitizer

    private func sanitizeSlug(_ raw: String) -> String {
        var slug = raw.lowercased()
        // Replace spaces and underscores with hyphens
        slug = slug.replacingOccurrences(of: " ", with: "-")
        slug = slug.replacingOccurrences(of: "_", with: "-")
        // Remove anything not alphanumeric or hyphen
        slug = slug.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        // Collapse multiple hyphens
        while slug.contains("--") {
            slug = slug.replacingOccurrences(of: "--", with: "-")
        }
        // Trim hyphens from edges
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        // Truncate if too long
        if slug.count > 60 {
            slug = String(slug.prefix(60))
        }
        return slug.isEmpty ? "screenshot" : slug
    }
}

// MARK: - Errors

enum NamingError: LocalizedError {
    case noAPIKey
    case freeLimitReached
    case imageLoadFailed
    case requestFailed
    case emptyResponse
    case parseError
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No API key set. Open Screenshot Namer settings to add one."
        case .freeLimitReached: return "Free tier limit reached for this month."
        case .imageLoadFailed: return "Could not load the screenshot image."
        case .requestFailed: return "Failed to build the API request."
        case .emptyResponse: return "Empty response from Claude API."
        case .parseError: return "Could not parse Claude's response."
        case .apiError(let msg): return "API error: \(msg)"
        }
    }
}
