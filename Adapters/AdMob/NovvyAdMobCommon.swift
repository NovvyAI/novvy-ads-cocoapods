import Foundation
import GoogleMobileAds
@_spi(Mediation) import NovvyAds

/// The pieces every format's loader needs. Kept in one file so the three loaders read as pure
/// callback translation.
///
/// Mirrors `NovvyAdMobCommon.kt` on Android one-to-one, minus `findActivity()` — see
/// ``NovvyAdMobErrorMapping/errorNoActivity`` for why that one has no iOS counterpart.
internal enum NovvyAdMobCommon {

    /// What the reward / interstitial requests declare as `imp.custom.creative_type[]`.
    ///
    /// **H5_ZIP only, for the mediation bring-up.** H5_ZIP is the creative this SDK actually sells,
    /// so the first thing an AdMob integration has to prove is that *that* creative fills, loads and
    /// renders through a waterfall — a run that filled with IMAGE instead would test the callback
    /// translation and nothing else. Declaring the one type is what makes the test conclusive: the
    /// server has no second option to fall back on, so a no-fill is a no-fill and not a silent
    /// substitution.
    ///
    /// **The timing bound is the thing to keep an eye on.** Every waterfall layer has a timeout
    /// window and a layer that overruns it is skipped outright — the auction we just won is thrown
    /// away before the load is ever reported. Our load callback means "material is on disk and
    /// display costs zero network", so the worst case, not the median, decides whether this ad
    /// source stays in the publisher's waterfall. Keep the creative bundles under 5MB and this path
    /// is comfortably inside a normal window; lose that discipline and the ad source gets skipped
    /// with no diagnostic anywhere.
    ///
    /// Changing this is a one-line edit, and that is the *point* of it being a constant: widen it to
    /// the other renderable types once the H5_ZIP path is proven end to end. Banner is **not**
    /// covered by this set — that format requests IMAGE only, decided inside the SDK.
    static let creativeTypes: [NovvyCreativeType] = [.h5Zip]

    /// What a failed ``adUnitId(from:)`` has to tell the publisher. Same text for all three formats.
    static let missingAdUnitIdMessage =
        "Novvy: the ad source's \"parameter\" field must be a JSON object holding the Novvy ad unit "
        + "id, e.g. {\"adUnitId\":\"app_xxxx/1234567890\"}"

    /// The AdMob UI settings key holding the custom event's free-text parameter.
    ///
    /// A literal because the iOS SDK exports no constant for it — Android has
    /// `MediationConfiguration.CUSTOM_EVENT_SERVER_PARAMETER_FIELD`, `GADMediationCredentials`
    /// just hands over an untyped `settings` dictionary.
    private static let parameterKey = "parameter"

    private static let adUnitIdKey = "adUnitId"

    /// The Novvy ad unit id out of the one value a publisher types into the AdMob dashboard.
    ///
    /// Everything else about this ad source — app id, endpoint, api key — comes from the host's own
    /// `NovvySDK.shared.initialize(...)` call, on purpose: a mistyped endpoint in a dashboard field
    /// is a silent no-fill with no diagnostic anywhere.
    ///
    /// **The `parameter` field is a JSON string, not the id itself** —
    /// `{"adUnitId":"app_xxxx/123"}`. That is how AdMob's own third-party ad-source parameters are
    /// shaped, and it is what leaves room for a second key later without a dashboard migration.
    ///
    /// A value that does *not* start with `{` is still accepted as a bare id: the custom-event form
    /// is a free-text box, and a publisher who typed only the id there should not be told their ad
    /// source is misconfigured. What is never accepted is malformed JSON or JSON without the key —
    /// that goes out as a `parameter`-shaped failure rather than as an ad unit id nobody
    /// provisioned, since `/bid` answers an unknown id with the same empty response as a real
    /// no-fill.
    static func adUnitId(from configuration: MediationAdConfiguration) -> String? {
        guard let raw = (configuration.credentials.settings[parameterKey] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else { return nil }

        guard raw.hasPrefix("{") else { return raw }

        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = (json[adUnitIdKey] as? String)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              !id.isEmpty
        else { return nil }

        return id
    }
}
