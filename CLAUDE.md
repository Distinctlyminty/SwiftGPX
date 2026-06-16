# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```sh
swift build                                    # build (CI also runs with -Xswiftc -warnings-as-errors)
swift test                                     # full test suite
swift test --filter SwiftGPXTests.ParserTests  # one suite
swift test --filter "Round trip/waypointsRoundTrip"  # one test (suite display name / function name)
```

CI matrix: `macos-26` with the bundled Swift 6 toolchain and `swift:6.0` Linux container. Linux builds rely on `FoundationXML`; the parser already conditionalises this. The CoreLocation convenience builder is gated by `#if canImport(CoreLocation)` and therefore not compiled on Linux — keep new CoreLocation-touching code inside that gate.

## Architecture

The library has three layers, and the round-trip property `parse(serialize(doc)) == doc` is the load-bearing contract that ties them together. Any change to one layer almost always needs a matching change in the others, plus a new case in `RoundTripTests`.

**Models** (`Sources/SwiftGPX/Models/`) — pure value types. All public types are `Sendable`, `Codable`, and `Equatable`; this is enforced by `.swiftLanguageMode(.v6)` in `Package.swift` and is non-negotiable for new public API. `GPXWaypoint` is shared across `<wpt>`, `<rtept>`, and `<trkpt>` because they have the same GPX schema. `GPXExtensions` carries typed fields for known fitness extensions plus a `custom: [GPXCustomExtension]` escape hatch — this escape hatch is what makes round-tripping safe for unknown elements; never silently drop unrecognised extension data.

**Parsing** (`Sources/SwiftGPX/Parsing/`) — `GPXParser` is a thin synchronous wrapper around Foundation's SAX `XMLParser`. The real work lives in `GPXParserDelegate`, which maintains a stack of `Frame` enum values, one per currently-open element of interest (`metadata`, `waypoint`, `route`, `track`, `trackSegment`, `extensions`, …). Leaf elements (`name`, `ele`, `time`, `hr`, …) don't get their own frame — they're folded into the top frame in `didEndElement` using the accumulated `characterBuffer`. A separate `garminTrackPointExtension` frame nests inside `extensions` to handle Garmin's `<gpxtpx:TrackPointExtension>` wrapper. Namespace prefixes are stripped (`stripPrefix`) so producers using non-standard prefixes still parse — `shouldProcessNamespaces = false` is intentional.

**Serialization** (`Sources/SwiftGPX/Serialization/`) — `GPXSerializer` produces deterministic byte-identical output for a given input (this is what makes round-trip tests possible). `GPXXMLWriter` is a private writer scoped to GPX's needs, not a general XML library. Two formatters worth knowing about: `formatCoordinate` always emits 6 decimal places (~11cm); `formatNumber` strips trailing zeros so `42.0` → `"42"` (matches what most fitness apps emit). The Garmin `xmlns:gpxtpx` declaration is only emitted when the document actually carries Garmin extension data — `documentUsesGarminExtensions` walks the document to decide.

## Conventions worth knowing

- **Foundation only.** No third-party runtime dependencies, ever.
- **Round-trip-or-it-didn't-happen.** Any new field on a model needs both serializer support and a case in `Tests/SwiftGPXTests/RoundTripTests.swift`. Behaviour changes (e.g. parsing a new extension) ship with a fixture in `Tests/SwiftGPXTests/Fixtures/` accessed via `Bundle.module.url(forResource:withExtension:subdirectory: "Fixtures")` — fixtures are wired through `resources: [.copy("Fixtures")]` in `Package.swift`.
- **Tests use swift-testing**, not XCTest: `import Testing`, `@Suite`, `@Test`, `#expect`, `#require`.
- `GPXDateFormatter` keeps three `ISO8601DateFormatter` singletons marked `nonisolated(unsafe)` — these are intentional to satisfy Swift 6 strict concurrency without per-parse allocation. Don't replace with per-call instances.
- Conventional commits (`feat:`, `fix:`, `docs:`, `chore:`, `test:`), subject under 70 characters. Update `CHANGELOG.md` under `## [Unreleased]` for any user-visible change. One concern per PR.
