# Changelog

## 1.1.3

- Align the provider request identity with @ai-sdk/open-responses 2.0.89 after comparing source, declarations and matching-release tests against 2.0.87. Offline validation passed: node Scripts/test-packages.mjs (56 packages, 3672 owning tests and 1760 compatibility tests), generation, tooling, isolation, and version selection. See Docs/Archive/WeeklyUpstreamAudit20261122.md for retained gaps. Paid provider calls were skipped.
  Compatibility: Source-compatible request-header update.
