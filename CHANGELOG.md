# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-15

### Added
- GPX 1.1 reading and writing with full coverage of metadata, waypoints, routes, and tracks.
- Garmin `TrackPointExtension` v1 & v2 plus ClueTrust GPXData parsing/serialization.
- Unknown extension elements preserved verbatim via `GPXExtensions.custom` for safe round-tripping.
- `GPXDocument.track(from:creator:name:heartRateAt:)` convenience builder over `[CLLocation]`.
- Synchronous, `Sendable` `GPXParser` backed by Foundation's `XMLParser` (or `FoundationXML` on Linux).
- Deterministic `GPXSerializer` with optional pretty-printing and per-document Garmin-namespace declaration.
- Swift 6 strict-concurrency conformance; all public value types are `Sendable`, `Codable`, and `Equatable`.
