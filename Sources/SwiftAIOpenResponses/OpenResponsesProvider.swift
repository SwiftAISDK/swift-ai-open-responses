import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import SwiftAIOpenAI

public typealias OpenResponsesTools = SwiftAIOpenAI.OpenResponsesTools
public typealias OpenResponsesErrorMetadata = SwiftAIOpenAI.OpenResponsesErrorMetadata
public typealias OpenResponsesFailedResponse = SwiftAIOpenAI.OpenResponsesFailedResponse

public struct OpenResponsesProviderSettings: Sendable {
    public var apiKey: String?
    /// Supplies a fresh API key before an authenticated request.
    public var apiKeyProvider: (@Sendable () async throws -> String)?
    public var headers: [String: String]
    /// Resolves provider headers before every generated or streamed response.
    public var headersProvider: (@Sendable () async throws -> [String: String])?
    public var transport: any AITransport
    public var strictResponseInput: Bool
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?

    public init(apiKey: String? = nil, apiKeyProvider: (@Sendable () async throws -> String)? = nil, headers: [String: String] = [:], headersProvider: (@Sendable () async throws -> [String: String])? = nil,
                transport: any AITransport = URLSessionTransport.shared, strictResponseInput: Bool = false,
                transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil) {
        self.apiKey = apiKey; self.apiKeyProvider = apiKeyProvider; self.headers = headers; self.headersProvider = headersProvider; self.transport = transport
        self.strictResponseInput = strictResponseInput; self.transformRequestBody = transformRequestBody
    }
}

/// An endpoint-specific Open Responses port using the existing shared Responses engine.
public final class OpenResponsesProvider: AIProvider, Sendable {
    public let providerID: String
    public let supportedCapabilities: Set<ModelCapability> = [.language]
    private let config: OpenAIModelConfiguration
    private let headersProvider: (@Sendable () async throws -> [String: String])?

    public init(
        name: String, url: String, configuration: OpenResponsesProviderSettings = .init(),
        customToolID: String = "open-responses.custom", structuredOutputs: Bool = true,
        getResponseErrorMetadata: (@Sendable (JSONValue) -> OpenResponsesErrorMetadata)? = nil,
        dynamicHeaders: (@Sendable () -> [String: String])? = nil,
        failedResponseHandler: (@Sendable (AIHTTPResponse) -> OpenResponsesFailedResponse)? = nil,
        userAgentSuffix: String? = nil
    ) throws {
        var configuration = configuration
        if let supplier = configuration.apiKeyProvider {
            let credential = AIAsyncCredential(supplier)
            configuration.apiKey = credential.placeholder
            configuration.transport = credential.resolvingTransport(configuration.transport)
        }
        providerID = "\(name).responses"
        var headers = normalizeHeaders(configuration.headers)
        if let apiKey = configuration.apiKey, headers["authorization"] == nil { headers["authorization"] = "Bearer \(apiKey)" }
        let endpoint = try requireURL(url)
        let base = "\(endpoint.scheme ?? "https")://\(endpoint.host ?? "")"
        var config = OpenAIModelConfiguration(http: .init(
            providerID: "\(name).responses", headers: headers, transport: configuration.transport,
            dynamicHeaders: dynamicHeaders, userAgentSuffix: userAgentSuffix ?? "ai-sdk-open-responses/2.0.77",
            url: { _, _ in endpoint }), baseURL: base, openAIBackedProviderRoot: nil)
        config.strictResponseInput = configuration.strictResponseInput
        config.transformRequestBody = configuration.transformRequestBody
        config.responsesRequestMode = .openResponses(providerOptionsName: name)
        config.openResponsesCustomToolID = customToolID
        config.supportsStructuredOutputs = structuredOutputs
        config.getResponseErrorMetadata = getResponseErrorMetadata
        if let failedResponseHandler {
            config.errorHandler = { response in
                let failure = failedResponseHandler(response)
                return .apiCall(AIAPICallError(provider: "\(name).responses", url: response.url?.absoluteString,
                    statusCode: failure.statusCode ?? response.statusCode, responseHeaders: response.headers,
                    responseBody: failure.responseBody, isRetryable: failure.isRetryable))
            }
        }
        self.config = config
        self.headersProvider = configuration.headersProvider
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        if let headersProvider {
            return OpenResponsesDynamicHeadersModel(modelID: modelID, config: config, headersProvider: headersProvider)
        }
        return OpenAICompatibleResponsesModel(modelID: modelID, config: config)
    }
    public func chatModel(_ modelID: String) throws -> any LanguageModel { try languageModel(modelID) }
    public func responses(_ modelID: String) throws -> any LanguageModel { try languageModel(modelID) }
    public func responsesModel(_ modelID: String) throws -> any LanguageModel { try languageModel(modelID) }
    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .embedding, modelID: modelID)
    }
    public func imageModel(_ modelID: String) throws -> any ImageModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .image, modelID: modelID)
    }
    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .transcription, modelID: modelID)
    }
    public func speechModel(_ modelID: String) throws -> any SpeechModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .speech, modelID: modelID)
    }
    public func videoModel(_ modelID: String) throws -> any VideoModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .video, modelID: modelID)
    }
    public func rerankingModel(_ modelID: String) throws -> any RerankingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .reranking, modelID: modelID)
    }
}

public extension AIProviders {
    static func openResponses(
        name: String, url: String, configuration: OpenResponsesProviderSettings,
        customToolID: String = "open-responses.custom", structuredOutputs: Bool = true,
        getResponseErrorMetadata: (@Sendable (JSONValue) -> OpenResponsesErrorMetadata)? = nil,
        dynamicHeaders: (@Sendable () -> [String: String])? = nil,
        failedResponseHandler: (@Sendable (AIHTTPResponse) -> OpenResponsesFailedResponse)? = nil,
        userAgentSuffix: String? = nil
    ) throws -> OpenResponsesProvider {
        try OpenResponsesProvider(name: name, url: url, configuration: configuration,
            customToolID: customToolID, structuredOutputs: structuredOutputs,
            getResponseErrorMetadata: getResponseErrorMetadata, dynamicHeaders: dynamicHeaders,
            failedResponseHandler: failedResponseHandler, userAgentSuffix: userAgentSuffix)
    }
}

private struct OpenResponsesDynamicHeadersModel: LanguageModel {
    let modelID: String
    let config: OpenAIModelConfiguration
    let headersProvider: @Sendable () async throws -> [String: String]
    var providerID: String { config.providerID }
    var supportedURLs: [String: [AISupportedURLPattern]] {
        OpenAICompatibleResponsesModel(modelID: modelID, config: config).supportedURLs
    }

    private func resolved(_ request: LanguageModelRequest) async throws -> OpenAICompatibleResponsesModel {
        try request.abortSignal?.throwIfAborted()
        var config = config
        let fresh = try await headersProvider()
        try request.abortSignal?.throwIfAborted()
        config.http.headers = prepareHeaders(fresh, defaultHeaders: config.http.headers)
        return OpenAICompatibleResponsesModel(modelID: modelID, config: config)
    }
    func generate(_ request: LanguageModelRequest) async throws -> TextGenerationResult {
        try await resolved(request).generate(request)
    }
    func stream(_ request: LanguageModelRequest) -> AsyncThrowingStream<LanguageStreamPart, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let model = try await resolved(request)
                    for try await part in model.stream(request) { continuation.yield(part) }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
