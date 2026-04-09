import Foundation

enum CodexAccountValidationService {
    private static let officialAPIBaseURL = "https://api.openai.com/v1"

    private struct Target {
        let baseURL: URL
        let headers: [String: String]
        let queryParams: [String: String]
    }

    static func validate(authData: Data, session: URLSession = .shared) async throws -> String {
        let target = try resolveTarget(from: authData)
        return try await executeRequest(target: target, session: session)
    }

    private static func resolveTarget(from authData: Data) throws -> Target {
        guard let object = try JSONSerialization.jsonObject(with: authData, options: []) as? [String: Any] else {
            throw validationError(code: 4, description: "auth.json is not a valid JSON object.")
        }

        guard let apiKey = normalizedString(object["OPENAI_API_KEY"]) else {
            throw validationError(code: 5, description: "OPENAI_API_KEY is missing in auth.json.")
        }

        let relayObject = (object["nolon"] as? [String: Any])?["relay"] as? [String: Any]
        let relayBaseURLString = normalizedString(relayObject?["base_url"])
        let relayHeaders = normalizedDictionary(relayObject?["headers"])
        let relayQueryParams = normalizedDictionary(relayObject?["query_params"])

        let baseURL: URL
        if let relayBaseURLString {
            guard let relayURL = URL(string: relayBaseURLString) else {
                throw validationError(code: 6, description: "Relay base_url is invalid: \(relayBaseURLString)")
            }
            baseURL = relayURL
        } else {
            guard let officialURL = URL(string: officialAPIBaseURL) else {
                throw validationError(code: 7, description: "Official OpenAI base URL is invalid.")
            }
            baseURL = officialURL
        }

        var headers = relayHeaders
        headers["Authorization"] = "Bearer \(apiKey)"
        return Target(baseURL: baseURL, headers: headers, queryParams: relayQueryParams)
    }

    private static func executeRequest(target: Target, session: URLSession) async throws -> String {
        guard let requestURL = responsesURL(baseURL: target.baseURL, queryParams: target.queryParams) else {
            throw validationError(code: 2, description: "Unable to build /v1/responses URL.")
        }

        let randomInput = "nolon-connectivity-\(UUID().uuidString.lowercased())"
        let requestBody: [String: Any] = [
            "model": "gpt-4.1-mini",
            "input": randomInput,
            "max_output_tokens": 1,
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody, options: [])

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (header, value) in target.headers {
            request.setValue(value, forHTTPHeaderField: header)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw validationError(code: 3, description: "Received an invalid HTTP response.")
        }

        if (200 ... 299).contains(httpResponse.statusCode) {
            return "Connected (\(httpResponse.statusCode)). Input: \(randomInput)"
        }

        let message = serverMessage(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
        throw validationError(
            code: httpResponse.statusCode,
            description: "Validation failed (\(httpResponse.statusCode)): \(message). Input: \(randomInput)"
        )
    }

    private static func responsesURL(baseURL: URL, queryParams: [String: String]) -> URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let segments = (components?.path ?? "")
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        let pathSegments: [String]
        if segments.last?.lowercased() == "v1" {
            pathSegments = segments + ["responses"]
        } else {
            pathSegments = segments + ["v1", "responses"]
        }
        components?.path = "/" + pathSegments.joined(separator: "/")

        if !queryParams.isEmpty {
            var queryItems = components?.queryItems ?? []
            for key in queryParams.keys {
                queryItems.removeAll { $0.name == key }
            }
            for (key, value) in queryParams.sorted(by: { $0.key < $1.key }) {
                queryItems.append(URLQueryItem(name: key, value: value))
            }
            components?.queryItems = queryItems
        }

        return components?.url
    }

    private static func serverMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: []) else { return nil }
        if let root = object as? [String: Any] {
            if let errorObject = root["error"] as? [String: Any],
               let message = normalizedString(errorObject["message"]) {
                return message
            }
            if let message = normalizedString(root["message"]) {
                return message
            }
        }
        if let text = String(data: data, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    private static func normalizedString(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizedDictionary(_ value: Any?) -> [String: String] {
        guard let raw = value as? [String: Any] else { return [:] }
        var result: [String: String] = [:]
        for (key, value) in raw {
            if let normalized = normalizedString(value) {
                result[key] = normalized
            }
        }
        return result
    }

    private static func validationError(code: Int, description: String) -> NSError {
        NSError(
            domain: "ProviderUsageEngine.CodexValidate",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }
}
