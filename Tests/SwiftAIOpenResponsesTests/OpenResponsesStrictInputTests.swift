@testable import SwiftAIOpenResponses
@testable import SwiftAIOpenAI
import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities
import Testing


@Test func openResponsesStrictInputUsesEasyMessageWithoutSyntheticID() throws {
    let prepared = openResponsesInput(
        from: [.assistant("Hello from assistant")],
        providerID: "test-provider.responses",
        providerOptionsName: "test-provider",
        strictResponseInput: true
    )

    #expect(prepared.input == [[
        "type": "message",
        "role": "assistant",
        "content": "Hello from assistant"
    ]])
}


@Test func openResponsesStrictInputPreservesGenuineCompletedItemID() throws {
    let message = AIMessage(role: .assistant, content: [
        .text("Hello from assistant", providerMetadata: [
            "test-provider": ["itemId": "msg_123"]
        ])
    ])
    let prepared = openResponsesInput(
        from: [message],
        providerID: "test-provider.responses",
        providerOptionsName: "test-provider",
        strictResponseInput: true
    )

    #expect(prepared.input == [[
        "id": "msg_123",
        "type": "message",
        "status": "completed",
        "role": "assistant",
        "content": [[
            "type": "output_text",
            "text": "Hello from assistant",
            "annotations": [],
            "logprobs": []
        ]]
    ]])
}


@Test func openResponsesProviderPropagatesStrictInputSetting() async throws {
    let transport = RecordingTransport(response: jsonResponse(
        #"{"id":"resp-1","status":"completed","output_text":"ok"}"#
    ))
    let provider = try AIProviders.openResponses(
        name: "test-provider",
        url: "https://responses.example.com/v1/responses",
        configuration: OpenResponsesProviderSettings(
            apiKey: "test-key",
            transport: transport,
            strictResponseInput: true
        )
    )

    _ = try await provider.languageModel("model").generate(
        LanguageModelRequest(messages: [.assistant("Prior answer")])
    )

    let body = try decodeJSONBody(try #require((await transport.requests()).first?.body))
    #expect(body["input"]?[0] == [
        "type": "message",
        "role": "assistant",
        "content": "Prior answer"
    ])
}