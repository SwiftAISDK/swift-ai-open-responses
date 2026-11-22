<!-- Generated distribution; edit the canonical repository. -->
# swift-ai-open-responses 1.1.3

Independent Swift-native port of Vercel AI SDK. Source and upstream dispositions are in PROVENANCE.json and Porting/.

## Distribution manifest

Add this package to your SwiftPM dependencies:

```swift
.package(url: "https://github.com/SwiftAISDK/swift-ai-open-responses.git", from: "1.1.3")
```

Products: `SwiftAIOpenResponses`.
Contribute and report issues in the canonical SwiftAISDK repository.

## Authored usage guide

# Open Responses for Swift

`SwiftAIOpenResponses` adds Open Responses to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/open-responses` and supports text generation.

Provider guide with models, options, streaming and errors:

- [Open Responses](https://swiftaisdk.github.io/SwiftAISDK/providers/open-responses-responses/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIOpenResponses` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIOpenResponses

let provider = try AIProviders.openResponses(
    name: "my-server",
    url: "https://example.com/v1/responses",
    configuration: OpenResponsesProviderSettings()
)
```

Pass credentials in the provider settings; the guide shows the supported options.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-open-responses` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
