import Foundation
import GoogleMobileAds
import UIKit
import NovvyAds

/// The AdMob custom-event adapter for Novvy inventory.
///
/// ### The class name is the integration
///
/// **`NovvyAdMobMediationAdapter` is typed by hand into the AdMob dashboard**, into the "Class Name"
/// field of a custom event ad source. It is looked up reflectively at runtime, so nothing about it
/// is checked at build time: rename it and every publisher who already configured this ad source
/// gets a silent no-fill with no diagnostic anywhere. The `@objc` name is what pins it — the Swift
/// symbol could be mangled, the Objective-C one is stable. Treat it as the most brittle name in this
/// repository.
///
/// The other half of the dashboard configuration is the "Parameter" field, which carries the Novvy
/// ad unit id — see ``NovvyAdMobCommon/adUnitId(from:)``.
///
/// ### What this class does and does not do
///
/// It is a router, and stateless on purpose: each `load…` builds a loader that owns the whole
/// lifetime of one ad and hands itself back to Google. All three loaders share the same opening
/// sequence — SDK initialized, ad unit id present, construct, wire the impression hook, load — and
/// differ only in which callbacks they translate.
///
/// Mirrors Android's `NovvyAdMobMediationAdapter` one-to-one.
@objc(NovvyAdMobMediationAdapter)
public final class NovvyAdMobMediationAdapter: NSObject, MediationAdapter {

    /// Kept in step with `NovvyAdsAdMob.podspec`'s `s.version`, by hand.
    ///
    /// There is no build-time constant to read it from the way Android has `BuildConfig` — a source
    /// pod compiles with whatever the host's build settings are, and nothing injects the podspec
    /// version into it. Reported to AdMob only for diagnostics, so drift here costs a confusing
    /// dashboard line, nothing functional.
    private static let adapterVersionString = "1.1.5"

    public override init() {
        super.init()
    }

    // ----------------------------------------------------------------------------- MediationAdapter

    public static func adapterVersion() -> VersionNumber {
        versionNumber(from: adapterVersionString)
    }

    public static func adSDKVersion() -> VersionNumber {
        versionNumber(from: NovvySDK.shared.version)
    }

    public static func networkExtrasClass() -> (any AdNetworkExtras.Type)? {
        // Nothing about a Novvy request is configurable per-request from the host side: creative
        // types, size and ad unit are all decided by the ad source's own configuration.
        nil
    }

    /// Not on the path a custom event takes.
    ///
    /// AdMob calls this only for ad sources it knows as first-class adapters; custom events go
    /// straight to `load…`. It is implemented anyway because the protocol offers it and a future
    /// promotion out of custom-event status would otherwise start failing — and it succeeds
    /// immediately because the real precondition is `NovvySDK.shared.initialize(...)`, which is the
    /// **host's** call to make with the host's own credentials. Every loader re-checks it for that
    /// reason.
    public static func setUp(
        with configuration: MediationServerConfiguration,
        completionHandler: @escaping GADMediationAdapterSetUpCompletionBlock
    ) {
        completionHandler(nil)
    }

    public func loadBanner(
        for adConfiguration: MediationBannerAdConfiguration,
        completionHandler: @escaping GADMediationBannerLoadCompletionHandler
    ) {
        NovvyBannerLoader(configuration: adConfiguration, completionHandler: completionHandler).load()
    }

    public func loadInterstitial(
        for adConfiguration: MediationInterstitialAdConfiguration,
        completionHandler: @escaping GADMediationInterstitialLoadCompletionHandler
    ) {
        NovvyInterstitialLoader(configuration: adConfiguration, completionHandler: completionHandler).load()
    }

    public func loadRewardedAd(
        for adConfiguration: MediationRewardedAdConfiguration,
        completionHandler: @escaping GADMediationRewardedLoadCompletionHandler
    ) {
        NovvyRewardedLoader(configuration: adConfiguration, completionHandler: completionHandler).load()
    }

    // --------------------------------------------------------------------------------- versioning

    /// `"1.1.5"` / `"1.1.6.0"` → ``VersionNumber``.
    ///
    /// AdMob's struct holds three components and ours may hold four, so a fourth is folded into the
    /// patch as `patch * 100 + build` — the convention Google's own adapters use, and the reason the
    /// multiplier is 100 rather than 10 is that it keeps folded versions ordered as long as the
    /// build number stays below 100.
    ///
    /// An unparseable string yields `0.0.0` rather than throwing: this is diagnostic metadata, and
    /// the mediation layer calls it while assembling an ad request. Failing there would take out ad
    /// serving over a cosmetic string.
    private static func versionNumber(from string: String) -> VersionNumber {
        let parts = string.split(separator: ".").map { Int($0) }
        guard parts.count >= 3, !parts.contains(where: { $0 == nil }) else {
            return VersionNumber(majorVersion: 0, minorVersion: 0, patchVersion: 0)
        }
        let components = parts.compactMap { $0 }
        let patch = components.count >= 4
            ? components[2] * 100 + components[3]
            : components[2]
        return VersionNumber(
            majorVersion: components[0],
            minorVersion: components[1],
            patchVersion: patch
        )
    }
}
