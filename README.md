# SwiftGPX

[![Sponsor](https://img.shields.io/github/sponsors/Distinctlyminty?label=Sponsor&logo=GitHub&logoColor=white&color=ea4aaa)](https://github.com/sponsors/Distinctlyminty)

A modern, Swift 6 GPX 1.1 library for reading and writing GPS Exchange Format files.

- Pure-Swift, Foundation-only (no third-party dependencies).
- Swift 6 strict concurrency. All public types are `Sendable`.
- First-class fitness extensions — Garmin `TrackPointExtension` v1 & v2, ClueTrust, bare COROS/Strava tags — without regex hacks.
- Round-trip safe: `parse(serialize(doc)) == doc` for every supported field.
- Lenient on parse, strict on emit: real-world quirks (odd timestamps, CDATA, GPX 1.0, unknown elements) parse cleanly, while the serializer refuses to produce schema-invalid XML.
- Built-in analysis: distance, duration, moving time, elevation gain/loss, bounds, Douglas–Peucker simplification.
- Strava-ready: upload validation and an export preset.
- SAX-based parser keeps memory bounded on large recorded tracks.
- Works on iOS 17+, macOS 14+, watchOS 10+, tvOS 17+, visionOS 1+, and Linux.

## Install

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/Distinctlyminty/SwiftGPX.git", from: "2.0.0")
```

…and depend on the `SwiftGPX` library product.

## Writing GPX

```swift
import SwiftGPX

var document = GPXDocument(creator: "MyApp")
var segment = GPXTrackSegment()
segment.points = [
    GPXWaypoint(latitude: 54.4609, longitude: -3.0886, time: .now),
    GPXWaypoint(latitude: 54.4612, longitude: -3.0890, time: .now),
]
document.tracks.append(GPXTrack(name: "Derwent Water", segments: [segment]))

let xml = try GPXSerializer().string(from: document)
```

The serializer throws `GPXError.invalidValue` rather than emitting invalid GPX — NaN/infinite numbers and out-of-range coordinates are rejected. By default it keeps `document.creator`; pass `GPXSerializer(creator: "OtherApp")` to override.

## Writing GPX with heart-rate extension

```swift
let document = GPXDocument.track(from: locations, name: "Morning paddle") { time in
    heartRateSamples.closestBPM(to: time)
}
let data = try GPXSerializer().data(from: document)
```

## Reading GPX

```swift
let document = try GPXParser().parse(contentsOf: url)
for track in document.tracks {
    for segment in track.segments {
        for point in segment.points {
            print(point.latitude, point.longitude, point.extensions?.heartRate as Any)
        }
    }
}
```

Parsing is lenient about real-world content — GPX 1.0 input, CDATA sections, variable fractional-second timestamps, compact UTC offsets, and unknown elements all parse; malformed optional values become `nil`. Structural problems (bad `lat`/`lon`, unsupported versions, malformed XML) throw a specific `GPXError`.

## Uploading to Strava

```swift
// Strava rejects files whose track points lack <time> — catch problems first:
let issues = document.validateForStrava()
guard issues.isEmpty else {
    issues.forEach { print($0) }   // "tracks[0].segments[0].points[42] has no <time> …"
    return
}

// Compact output; "with Barometer" makes Strava trust the file's elevation data.
let serializer = GPXSerializer.strava(appName: "PaddlePal", hasBarometer: true)
let upload = try serializer.data(from: document)
```

`validate()` (without the Strava rules) reports every out-of-range or non-finite value the serializer would reject, in one pass.

## Analysing tracks

```swift
let stats = track.statistics()           // 0.5 m/s moving threshold suits paddling
stats.distance                           // meters, haversine
stats.duration                           // elapsed, including pauses
stats.movingTime                         // pauses and drift excluded
stats.elevationGain; stats.elevationLoss

let box = document.bounds                // GPXBounds containing every point
let overview = track.simplified(tolerance: 10)   // Douglas–Peucker, meters
let single = track.mergingSegments()     // join GPS-dropout segment splits
```

## Supported extensions

| Namespace | Fields |
| --- | --- |
| Garmin TrackPointExtension v1 (`http://www.garmin.com/xmlschemas/TrackPointExtension/v1`) | `hr`, `cad`, `atemp`, `wtemp`, `depth` |
| Garmin TrackPointExtension v2 (`http://www.garmin.com/xmlschemas/TrackPointExtension/v2`) | adds `speed`, `course`, `bearing` |
| ClueTrust GPXData | `hr`, `cadence`, `temp` |
| Bare tags (Strava generic, COROS) | `heartrate`, `cadence`, `temperature`, `power` |
| Unknown elements | preserved verbatim in `GPXExtensions.custom`, with root namespace declarations kept in `GPXDocument.namespaces` |

On output, the Garmin namespace is declared only when Garmin fields are present — v2 when `speed`/`course`/`bearing` are used, v1 otherwise.

## License

MIT — see [LICENSE](LICENSE).
