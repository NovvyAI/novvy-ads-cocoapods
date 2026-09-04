import Foundation
import GoogleMobileAds
import NovvyAds

/// ``NovvyError`` → the `NSError` AdMob's mediation layer expects.
///
/// The domain string is ours, not Google's: AdMob prints it verbatim in the publisher's mediation
/// logs, and it is the only place the failure is attributed to Novvy rather than to "a custom
/// event". It names the platform too, so a support ticket pasted out of a dashboard says which SDK
/// produced it without anyone having to ask.
///
/// The codes are deliberately stable small integers rather than the enum's case order — a case
/// inserted into ``NovvyError`` would shift every number below it, and these end up in a
/// publisher's dashboards and support tickets. They match Android's `NovvyAdMobErrorMapping`
/// one-to-one for exactly that reason: the same failure has to read as the same failure on both
/// platforms.
internal enum NovvyAdMobErrorMapping {

    static let domain = "ai.novvy.ios.mediation.admob"

    /// Not a load failure at all: the host never called `NovvySDK.shared.initialize(...)`.
    static let errorNotInitialized = 101

    /// The dashboard's `parameter` field is empty, or holds JSON with no usable `adUnitId` — the one
    /// thing the publisher has to fill in.
    static let errorMissingAdUnitId = 102

    // 103 is `ERROR_NO_ACTIVITY`, **Android-only and deliberately left as a gap.** Android's
    // `showAd` receives a `Context` that may have no Activity behind it and has to fail explicitly;
    // iOS's `present(from:)` is handed a `UIViewController` by the mediation layer, so the failure
    // has no iOS counterpart to report. Renumbering to close the gap would be worse than the gap:
    // these codes are compared across platforms in dashboards and tickets, so 111 has to mean
    // "no fill" on both.

    /// `present(from:)` arrived with nothing loaded, or with an ad already on screen.
    static let errorNotReady = 104

    private static let errorInvalidRequest = 110
    private static let errorNoFill = 111
    private static let errorTimeout = 112
    private static let errorInternal = 113

    static func toAdError(_ error: NovvyError) -> NSError {
        switch error {
        case .invalidRequest:
            return adError(errorInvalidRequest, "Novvy: invalid request")
        // The three "the auction produced nothing usable" shapes are one fact as far as a waterfall
        // is concerned: move to the next layer. Distinguishing them in the dashboard would invite a
        // publisher to act on a difference that does not change what they can do — so they share a
        // code, and the discriminant rides along in the message for our own support reads.
        case .noFill, .noBid, .noData:
            return adError(errorNoFill, "Novvy: no fill (\(error.errorDescription ?? "unknown"))")
        case .timeout:
            return adError(errorTimeout, "Novvy: timed out")
        case .encodingFailed:
            return adError(errorInternal, "Novvy: encoding failed")
        case .internalError(let details):
            return adError(errorInternal, "Novvy: \(details)")
        }
    }

    static func adError(_ code: Int, _ message: String) -> NSError {
        NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
