# Contributing to SwiftGPX

Thanks for your interest. SwiftGPX is small and opinionated by design.

## Ground rules

- Foundation only. No third-party runtime dependencies.
- All public types stay `Sendable`. New API must compile under Swift 6 strict concurrency.
- Every new field gets a round-trip test in `RoundTripTests` — parse → serialize → parse must equal the original.
- Behaviour changes ship with a fixture. Bug reports without one will be asked for one.

## Running the tests

```sh
swift test
```

Tests are expected to pass on macOS and Linux.

## Commit style

Conventional commits — `feat:`, `fix:`, `docs:`, `chore:`, `test:`. Keep the subject under 70 characters.

## Pull requests

- One concern per PR.
- Update `CHANGELOG.md` under `## [Unreleased]`.
- CI must be green before merge.
