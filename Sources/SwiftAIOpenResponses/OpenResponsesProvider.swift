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
    public var headers: [String: String]
    public var transport: any AITransport
    public var strictResponseInput: Bool
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?

    public init(apiKey: String? = nil, headers: [String: String] = [:],
                transport: any AITransport = URLSessionTransport.shared, strictResponseInput: Bool = false,
                transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil) {
        self.apiKey = apiKey; self.headers = headers; self.transport = transport
        self.strictResponseInput = strictResponseInput; self.transformRequestBody = transformRequestBody
    }
}

/// An endpoint-specific Open Responses port using the existing shared Responses engine.
public final class OpenResponsesProvider: AIProvider, Sendable {
    public let providerID: String
    public let supportedCapabilities: Set<ModelCapability> = [.language]
    private let config: OpenAIModelConfiguration

    public init(
        name: String, url: String, configuration: OpenResponsesProviderSettings = .init(),
        customToolID: String = "open-responses.custom", structuredOutputs: Bool = true,
        getResponseErrorMetadata: (@Sendable (JSONValue) -> OpenResponsesErrorMetadata)? = nil,
        dynamicHeaders: (@Sendable () -> [String: String])? = nil,
        failedResponseHandler: (@Sendable (AIHTTPResponse) -> OpenResponsesFailedResponse)? = nil,
        userAgentSuffix: String? = nil
    ) throws {
        providerID = "\(name).responses"
        var headers: [String: String] = [:]
        if let apiKey = configuration.apiKey { headers["Authorization"] = "Bearer \(apiKey)" }
        headers.merge(configuration.headers) { _, custom in custom }
        let endpoint = try requireURL(url)
        let base = "\(endpoint.scheme ?? "https")://\(endpoint.host ?? "")"
        var config = OpenAIModelConfiguration(http: .init(
            providerID: "\(name).responses", headers: headers, transport: configuration.transport,
            dynamicHeaders: dynamicHeaders, userAgentSuffix: userAgentSuffix ?? "ai-sdk-open-responses/2.0.73",
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
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        OpenAICompatibleResponsesModel(modelID: modelID, config: config)
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
