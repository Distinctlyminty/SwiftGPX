import Foundation

extension GPXSerializer {
    /// A serializer configured for Strava upload.
    ///
    /// Sets the creator to `appName`, or `"<appName> with Barometer"` when
    /// `hasBarometer` is true — Strava trusts the file's elevation data instead of
    /// re-deriving it when the creator advertises a barometer. Output is compact
    /// (no pretty-printing) to keep uploads small.
    ///
    /// Strava requires a `<time>` on every track point; run
    /// ``GPXDocument/validateForStrava()`` before serializing to catch that early.
    public static func strava(appName: String, hasBarometer: Bool = false) -> GPXSerializer {
        GPXSerializer(
            creator: hasBarometer ? "\(appName) with Barometer" : appName,
            prettyPrint: false
        )
    }
}
