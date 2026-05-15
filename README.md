# SwiftGPX

A modern, Swift 6 GPX 1.1 library for reading and writing GPS Exchange Format files.

- Pure-Swift, Foundation-only (no third-party dependencies).
- Swift 6 strict concurrency. All public types are `Sendable`.
- First-class fitness extensions — Garmin `TrackPointExtension` v1 & v2, ClueTrust — without regex hacks.
- Round-trip safe: `parse(serialize(doc)) == doc` for every supported field.
- Actor-isolated SAX parser keeps memory bounded on large recorded tracks.
- Works on iOS 17+, macOS 14+, watchOS 10+, tvOS 17+, visionOS 1+, and Linux.

## Install

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/Sailr-Solutions-Ltd/SwiftGPX.git", from: "0.1.0")
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

let xml = GPXSerializer(creator: "MyApp").string(from: document)
```

## Writing GPX with heart-rate extension

```swift
let document = GPXDocument.track(from: locations, name: "Morning paddle") { time in
    heartRateSamples.closestBPM(to: time)
}
let data = GPXSerializer(creator: "MyApp").data(from: document)
```

## Reading GPX

```swift
let document = try await GPXParser().parse(contentsOf: url)
for track in document.tracks {
    for segment in track.segments {
        for point in segment.points {
            print(point.latitude, point.longitude, point.extensions?.heartRate as Any)
        }
    }
}
```

## Supported extensions

| Namespace | Fields |
| --- | --- |
| Garmin TrackPointExtension v1 (`http://www.garmin.com/xmlschemas/TrackPointExtension/v1`) | `hr`, `cad`, `atemp`, `wtemp`, `depth` |
| Garmin TrackPointExtension v2 (`http://www.garmin.com/xmlschemas/TrackPointExtension/v2`) | adds `speed`, `course`, `bearing` |
| ClueTrust GPXData | `hr`, `cadence`, `temp` |
| Unknown elements | preserved verbatim in `GPXExtensions.custom` |

## License

MIT — see [LICENSE](LICENSE).
