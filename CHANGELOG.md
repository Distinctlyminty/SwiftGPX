# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- `<bounds>` with missing or malformed attributes is now skipped instead of silently
  becoming `(0, 0, 0, 0)`.
- CDATA sections (`<![CDATA[...]]>`) are no longer dropped — their text now lands in the
  surrounding element's value.
- Children of unknown wrapper elements no longer leak into the enclosing element (e.g.
  `<metadata><foo><name>X</name></foo></metadata>` no longer sets the metadata name).
- A waypoint with a missing or malformed `lat`/`lon` now aborts parsing immediately with
  the specific error instead of continuing to the end of the document.
- Timestamps with 1–6 fractional-second digits, compact UTC offsets (`+0100`), or a
  missing zone designator (treated as UTC) now parse instead of silently becoming `nil`.

### Changed
- **Breaking:** empty leaf elements (`<name></name>`) now round-trip as empty strings
  instead of being dropped.
- **Breaking:** `GPXSerializer.data(from:)` and `string(from:)` now `throw` —
  non-finite numbers (NaN/infinity) and out-of-range coordinates raise
  `GPXError.invalidValue` instead of producing invalid XML.
- **Breaking:** `GPXSerializer(creator:)` now defaults to `nil`, which preserves
  `GPXDocument.creator`; previously the default `"SwiftGPX"` silently replaced it.
- **Breaking:** the parser now rejects GPX versions other than 1.0/1.1 with
  `GPXError.unsupportedVersion`, and the serializer always emits `version="1.1"`.
- The Garmin TrackPointExtension namespace is now version-aware: documents using
  `speed`/`course`/`bearing` declare the v2 namespace; v1 is kept otherwise.

### Added
- `GPXDocument.namespaces` preserves extra namespace declarations from the root
  `<gpx>` element so custom extensions round-trip with valid, declared prefixes.
  Custom extensions with undeclared prefixes are emitted with the prefix stripped.
- `GPXDocument.validate()` reports every structural problem (out-of-range or
  non-finite values) in one pass, and `validateForStrava()` adds Strava's upload
  requirements: a `<time>` on every track point and monotonic timestamps.
- `GPXSerializer.strava(appName:hasBarometer:)` preset — compact output with the
  `"<app> with Barometer"` creator convention Strava uses to trust elevation data.
- Bare `<heartrate>`, `<temperature>`, and `<power>` extension tags (Strava generic
  extensions, COROS exports) now parse into the typed `GPXExtensions` fields.
- Analysis API: `GPXWaypoint.distance(to:)` (haversine), `GPXBounds(containing:)` /
  `formUnion(_:)` and computed `bounds` on segments, tracks, and documents.
- `GPXTrackSegment.statistics()` / `GPXTrack.statistics()` — distance, elapsed
  duration, moving time (threshold-based, paddling-friendly 0.5 m/s default), and
  elevation gain/loss.
- Douglas–Peucker track simplification: `simplified(tolerance:)` on segments and
  tracks (iterative, safe for 50k+-point recordings; kept points retain all values).
- `GPXTrack.mergingSegments()` concatenates segments for uploads where GPS dropouts
  would otherwise split a workout.

## [0.1.0] - 2026-05-15

### Added
- GPX 1.1 reading and writing with full coverage of metadata, waypoints, routes, and tracks.
- Garmin `TrackPointExtension` v1 & v2 plus ClueTrust GPXData parsing/serialization.
- Unknown extension elements preserved verbatim via `GPXExtensions.custom` for safe round-tripping.
- `GPXDocument.track(from:creator:name:heartRateAt:)` convenience builder over `[CLLocation]`.
- Synchronous, `Sendable` `GPXParser` backed by Foundation's `XMLParser` (or `FoundationXML` on Linux).
- Deterministic `GPXSerializer` with optional pretty-printing and per-document Garmin-namespace declaration.
- Swift 6 strict-concurrency conformance; all public value types are `Sendable`, `Codable`, and `Equatable`.
