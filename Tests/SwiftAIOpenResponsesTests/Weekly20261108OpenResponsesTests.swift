import Foundation
import Testing
import SwiftAIProvider
import SwiftAITransport
@testable import SwiftAIOpenResponses

@Suite struct Weekly20261108OpenResponsesTests {
    @Test func responseCreatedUsesServerMetadata() async throws {
        let events = #"{"type":"response.created","response":{"id":"resp","model":"server-model","created_at":1750000000,"output":[]}}"#
        let transport = RecordingTransport(response: AIHTTPResponse(statusCode: 200, headers: ["content-type": "text/event-stream"], body: Data("data: \(events)\n\ndata: [DONE]\n\n".utf8)))
        let provider = try OpenResponsesProvider(name: "custom", url: "https://api.test/responses", configuration: .init(apiKey: "key", transport: transport))
        var metadata: AIResponseMetadata?
        for try await part in try provider.languageModel("requested-model").stream(.init(messages: [.user("Hi")])) {
            if case let .responseMetadata(value) = part { metadata = value }
        }
        #expect(metadata?.id == "resp"); #expect(metadata?.modelID == "server-model")
        #expect(metadata?.timestamp == Date(timeIntervalSince1970: 1750000000))
    }
}
