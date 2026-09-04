import Foundation
import GoogleMobileAds
import UIKit
@_spi(Mediation) import NovvyAds

/// One rewarded ad, from `loadRewardedAd` to `rewardedAdDidClose`.
///
/// The class is both the ``MediationRewardedAd`` handed back to Google and the
/// `NovvyRewardedAdDelegate` that drives it — the two are one object's worth of state (the Novvy ad,
/// the show-time event delegate), and splitting them would only add a field pointing each at the
/// other. Same shape as Android's `NovvyRewardedLoader`.
internal final class NovvyRewardedLoader: NSObject, MediationRewardedAd, NovvyRewardedAdDelegate {

    private let configuration: MediationRewardedAdConfiguration
    private let loadCompletionHandler: GADMediationRewardedLoadCompletionHandler

    /// The **return value** of the load completion handler, and the only channel for every
    /// display-time event. Easiest thing in this whole adapter to forget to store — without it the
    /// ad shows and AdMob records nothing at all.
    private var eventDelegate: MediationRewardedAdEventDelegate?

    private var novvyAd: NovvyRewardedAd?

    /// A deliberate strong reference to `self`, held only between ``load()`` and whichever callback
    /// resolves it.
    ///
    /// **The iOS-only hazard in this adapter.** Novvy's `delegate` properties are `weak`, and
    /// nothing on the AdMob side retains a loader before it is handed back through the completion
    /// handler — Google only takes ownership on success, and on Android the equivalent object is
    /// kept alive by a strong listener reference instead. Without this, the loader is deallocated
    /// the moment `loadRewardedAd(for:completionHandler:)` returns, the load lands on a `nil`
    /// delegate, the completion handler is never called, and the waterfall layer sits there until
    /// AdMob times it out — a failure that looks exactly like slow inventory.
    ///
    /// Cleared on both resolution paths by ``release()``, so the cycle lives for one load. The
    /// SDK answers every `load()` with either a success or a failure, so there is no third path
    /// where this stays set.
    private var selfRetain: NovvyRewardedLoader?

    init(
        configuration: MediationRewardedAdConfiguration,
        completionHandler: @escaping GADMediationRewardedLoadCompletionHandler
    ) {
        self.configuration = configuration
        self.loadCompletionHandler = completionHandler
        super.init()
    }

    func load() {
        selfRetain = self

        // No wait, no queue, no `onComplete` orchestration: the SDK chains the UA / IDFA /
        // device-id fetches itself and treats a cold first load as a supported path. The only hard
        // dependency is the endpoint, which initialize() assigns synchronously — so `isInitialized`
        // really is the whole precondition.
        guard NovvySDK.shared.isInitialized else {
            fail(
                NovvyAdMobErrorMapping.adError(
                    NovvyAdMobErrorMapping.errorNotInitialized,
                    "Novvy: NovvySDK.shared.initialize(...) has not been called by the host app"
                )
            )
            return
        }
        guard let adUnitId = NovvyAdMobCommon.adUnitId(from: configuration) else {
            fail(
                NovvyAdMobErrorMapping.adError(
                    NovvyAdMobErrorMapping.errorMissingAdUnitId,
                    NovvyAdMobCommon.missingAdUnitIdMessage
                )
            )
            return
        }

        let ad = NovvyRewardedAd(adUnitId: adUnitId, creativeTypes: NovvyAdMobCommon.creativeTypes)
        // **`reportImpression` belongs here and nowhere else.** The hook fires off the SDK's own
        // viewability gate; wiring it to `rewardedAdDidShow` instead would count an impression the
        // moment the creative mounts, which inflates our reported impressions, dilutes the eCPM
        // AdMob computes for this ad source, and eventually gets it switched off.
        //
        // Set before load() only for readability — the hook is stored on the engine and rewired
        // onto each loaded ad as it lands, so the ordering is not load-bearing.
        ad.setImpressionHook { [weak self] in self?.eventDelegate?.reportImpression() }
        ad.delegate = self
        novvyAd = ad
        ad.load()
    }

    // ------------------------------------------------------------------------ MediationRewardedAd

    func present(from viewController: UIViewController) {
        guard let ad = novvyAd, ad.isReady else {
            // Our `show(from:)` returns silently on its own preconditions, so the adapter has to
            // pre-check them: AdMob needs an explicit failure or the ad slot hangs waiting for a
            // `willPresentFullScreenView` that will never come.
            eventDelegate?.didFailToPresentWithError(
                NovvyAdMobErrorMapping.adError(
                    NovvyAdMobErrorMapping.errorNotReady,
                    "Novvy: no ad is ready to show"
                )
            )
            return
        }
        ad.show(from: viewController)
    }

    // --------------------------------------------------------------------- NovvyRewardedAdDelegate

    func rewardedAdDidLoad(_ ad: NovvyRewardedAd) {
        eventDelegate = loadCompletionHandler(self, nil)
    }

    func rewardedAd(_ ad: NovvyRewardedAd, didFailToLoadWithError error: NovvyError) {
        fail(NovvyAdMobErrorMapping.toAdError(error))
    }

    func rewardedAdDidShow(_ ad: NovvyRewardedAd) {
        eventDelegate?.willPresentFullScreenView()
        // AdMob's vocabulary for "the rewarded unit's qualifying view began". Its counterpart
        // `didEndVideo()` is deliberately never sent: a Novvy REWARD ad is not necessarily a video
        // (IMAGE, H5 and CUSTOM fill this format too), and the SDK reports no playback completion
        // for the ones that are. Reward crediting runs through `didRewardUser`, which we do send.
        eventDelegate?.didStartVideo()
    }

    func rewardedAd(_ ad: NovvyRewardedAd, didEarnReward reward: NovvyReward) {
        // Our semantics — min_view_duration elapsed *and* the user actually closed the ad — put
        // this strictly before the close callback, which is exactly the order AdMob expects. No
        // buffering or reordering needed.
        //
        // Nothing from `reward` is passed along, and there is nothing to pass: iOS's
        // `didRewardUser()` takes no argument at all (unlike Android's `onUserEarnedReward(item)`),
        // because AdMob's model is that the reward is configured **on the ad unit** and its
        // server-side reward overrides any adapter value anyway.
        eventDelegate?.didRewardUser()
    }

    func rewardedAdDidClose(_ ad: NovvyRewardedAd) {
        eventDelegate?.willDismissFullScreenView()
        eventDelegate?.didDismissFullScreenView()
        release()
    }

    private func fail(_ error: NSError) {
        _ = loadCompletionHandler(nil, error)
        release()
    }

    private func release() {
        novvyAd?.destroy()
        novvyAd = nil
        selfRetain = nil
    }
}
