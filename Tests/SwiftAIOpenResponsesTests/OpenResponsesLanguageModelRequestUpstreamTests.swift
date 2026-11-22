@testable import SwiftAIOpenResponses
@testable import SwiftAIOpenAI
@testable import SwiftAIProvider
@testable import SwiftAIProviderUtilities
@testable import SwiftAITransport
import Foundation
import Testing

// Translated request-shape cases from
// packages/open-responses/src/responses/open-responses-language-model.test.ts
// (snapshots in __snapshots__/open-responses-language-model.test.ts.snap).

private let lmstudioBasicResponse = #"""
{"id":"resp_551daeb1a02e4fcaf9ab76ed29f821a6db2df1883e55652c","object":"response","created_at":1768900049,"completed_at":1768900162,"status":"completed","incomplete_details":null,"model":"mistralai/ministral-3-14b-reasoning","previous_response_id":null,"instructions":null,"output":[{"id":"rs_3l1z5wpifxkwxhj459ya7","type":"reasoning","status":"completed","summary":[],"content":[{"type":"reasoning_text","text":"reasoning content"}]},{"id":"msg_p1y190hl7hj1xyfqr1cir","type":"message","role":"assistant","status":"completed","content":[{"type":"output_text","text":"text content","annotations":[],"logprobs":[]}]}],"error":null,"tools":[],"usage":{"input_tokens":136,"output_tokens":3677,"total_tokens":3813,"input_tokens_details":{"cached_tokens":0},"output_tokens_details":{"reasoning_tokens":2456}}}
"""#

private func lmstudio() throws -> (any LanguageModel, RecordingTransport) {
    let transport = RecordingTransport(response: jsonResponse(lmstudioBasicResponse))
    let provider = try AIProviders.openResponses(
        name: "lmstudio",
        url: "https://localhost:1234/v1/responses",
        configuration: OpenResponsesProviderSettings(transport: transport)
    )
    return (try provider.languageModel("gemma-7b-it"), transport)
}

private func sentBody(_ request: LanguageModelRequest) async throws -> (JSONValue, TextGenerationResult) {
    let (model, transport) = try lmstudio()
    let result = try await model.generate(request)
    return (try decodeJSONBody(try #require(await transport.requests().first?.body)), result)
}

private let helloInput: JSONValue = [[
    "type": "message", "role": "user",
    "content": [["type": "input_text", "text": "Hello"]]
]]

@Suite("Open Responses language model requests (upstream)")
struct OpenResponsesLanguageModelRequestUpstreamTests {
    @Test("basic generation should send correct request body and content")
    func basicGeneration() async throws {
        let (body, result) = try await sentBody(LanguageModelRequest(messages: [.user("Hello")]))
        #expect(body == ["input": helloInput, "model": "gemma-7b-it"])
        #expect(result.text == "text content")
        #expect(result.usage?.inputTokens == 136)
        #expect(result.usage?.outputTokens == 3677)
    }

    @Test("request parameters should send correct request body")
    func requestParameters() async throws {
        let schema: JSONValue = ["type": "object", "properties": ["status": ["type": "string"]], "required": ["status"]]
        let (body, _) = try await sentBody(LanguageModelRequest(
            messages: [.user("Hello")], temperature: 0.5, topP: 0.9, presencePenalty: 0.1, frequencyPenalty: 0.2,
            maxOutputTokens: 100,
            responseFormat: .json(schema: schema, name: "response", description: "Example response schema")))
        #expect(body == [
            "frequency_penalty": 0.2, "input": helloInput, "max_output_tokens": 100, "model": "gemma-7b-it",
            "presence_penalty": 0.1, "temperature": 0.5,
            "text": ["format": [
                "description": "Example response schema", "name": "response", "schema": schema,
                "strict": true, "type": "json_schema"
            ]],
            "top_p": 0.9
        ])
    }

    @Test(arguments: [("high", "high"), ("minimal", "low"), ("none", "none"), ("xhigh", "xhigh"), ("max", "max")])
    func topLevelReasoning(reasoning: String, effort: String) async throws {
        let (body, _) = try await sentBody(LanguageModelRequest(messages: [.user("Hello")], reasoning: reasoning))
        #expect(body["reasoning"] == ["effort": .string(effort)])
    }

    @Test("should not set reasoning when not specified")
    func noReasoning() async throws {
        let (body, _) = try await sentBody(LanguageModelRequest(messages: [.user("Hello")]))
        #expect(body["reasoning"] == nil)
    }

    @Test("should join multiple system messages with newlines")
    func systemInstructions() async throws {
        let (body, _) = try await sentBody(LanguageModelRequest(messages: [
            .system("You are a helpful assistant."), .system("Always be concise."), .user("Hello")
        ]))
        #expect(body["instructions"] == "You are a helpful assistant.\nAlways be concise.")
        #expect(body["input"] == helloInput)
    }

    @Test("unsupported stopSequences, topK and seed produce warnings")
    func unsupportedSettingsWarn() async throws {
        let (_, result) = try await sentBody(LanguageModelRequest(
            messages: [.user("Hello")], topK: 3, seed: 7, stopSequences: ["END"]))
        let features = Set(result.warnings.compactMap(\.feature))
        #expect(features.isSuperset(of: ["stopSequences", "topK", "seed"]))
    }
}
