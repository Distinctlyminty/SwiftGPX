# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.2] - 2026-10-06

### Fixed
- Parsing a track or route no longer takes quadratic time. Each closing `<trkpt>`/`<rtept>`
  copied every point parsed so far, so a 20,000-point recording took seconds and an
  80,000-point one took minutes; parse time is now linear in file size.
- On Linux, `parse(_:)` and `parse(contentsOf:)` no longer reject documents larger than
  10 MB with `GPXError.malformedXML`.
- Elements inside `<extensions>` whose names match GPX structure (`metadata`, `wpt`, `trk`,
  `link`, …) no longer overwrite the document's own metadata or add phantom waypoints,
  tracks, and links. They are kept as custom extension data like any other element.
- Structural elements are now only recognised under the parent the GPX schema gives them.
  An attribute-only `<email>` or `<bounds>` inside an unknown wrapper no longer closes that
  wrapper early (leaking the wrapper's later children into its parent), and containers
  nested in unknown wrappers are ignored along with the wrapper.
- Unknown children of a Garmin `TrackPointExtension` wrapper are no longer dropped — they
  land in `GPXExtensions.custom` like other unrecognised extension elements.
- Integer extension and waypoint values written as decimals (`<hr>72.0</hr>`,
  `<sat>7.0</sat>`) now parse instead of becoming `nil`. A known extension element whose
  text isn't a usable number is preserved in `custom` rather than discarded.
- Childless custom extension elements (`<app:flag/>`) are preserved with an empty value, so
  `GPXCustomExtension` values with an empty `value` now round-trip.
- `NaN`/`inf` are no longer accepted as numbers: in `lat`/`lon` they raise
  `GPXError.invalidCoordinate`, and in optional values (`<ele>NaN</ele>`, `<bounds>`) they
  become `nil`. Previously they parsed into documents the serializer then refused to write.
- An `<extensions>` block that carries no data now parses as `nil` rather than an empty
  `GPXExtensions`, matching what the serializer emits for it.
- An XML document whose root element is not `<gpx>` now raises `GPXError.malformedXML`
  instead of parsing "successfully" into an empty document.
- The serializer no longer emits malformed XML for text containing characters XML 1.0
  cannot represent (most control characters) — they are dropped. Carriage returns, and
  tabs/newlines in attribute values, are written as character references so they survive
  a round trip instead of being normalized away by the reader.
- `GPXDocument.namespaces` entries that would make the root element malformed — a prefix
  the serializer already declares (`xsi`, or `gpxtpx` when Garmin fields are present), a
  prefix that isn't a valid XML name, or an empty URI — are skipped instead of written.
- Custom extension names containing characters an XML element name cannot hold are written
  with those characters replaced by `_` instead of producing malformed XML.
- Garmin `TrackPointExtension` children are now written in the order the Garmin schema
  requires (`atemp`, `wtemp`, `depth`, `hr`, `cad`, `speed`, `course`, `bearing`).
- `validate()` now reports non-finite values in route-, track-, and segment-level
  extensions, which the serializer already rejected.
- `simplified(tolerance:)` no longer keeps every point of a straight line that crosses the
  antimeridian.
- Numbers that round to zero at 7 decimal places are written as `0`, not `-0`.

## [2.0.1] - 2026-06-16

### Fixed
- Truncated documents (input ending mid-element) now consistently raise
  `GPXError.malformedXML` on Linux, matching Darwin. Linux's `XMLParser` does not flag the
  truncation itself, so the parser now detects the unclosed elements directly.

## [2.0.0] - 2026-06-15

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
