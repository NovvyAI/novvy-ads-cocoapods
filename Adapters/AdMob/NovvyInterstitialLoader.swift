import Foundation
import GoogleMobileAds
import UIKit
@_spi(Mediation) import NovvyAds

/// One interstitial ad. Structurally identical to ``NovvyRewardedLoader`` minus the reward callback
/// — see that class for the reasoning behind each step.
internal final class NovvyInterstitialLoader: NSObject, MediationInterstitialAd,
                                              NovvyInterstitialAdDelegate {

    private let configuration: MediationInterstitialAdConfiguration
    private let loadCompletionHandler: GADMediationInterstitialLoadCompletionHandler

    private var eventDelegate: MediationInterstitialAdEventDelegate?
    private var novvyAd: NovvyInterstitialAd?
    /// See ``NovvyRewardedLoader/selfRetain`` — without it the loader dies before its load resolves
    /// and the waterfall layer hangs until AdMob times it out.
    private var selfRetain: NovvyInterstitialLoader?

    init(
        configuration: MediationInterstitialAdConfiguration,
        completionHandler: @escaping GADMediationInterstitialLoadCompletionHandler
    ) {
        self.configuration = configuration
        self.loadCompletionHandler = completionHandler
        super.init()
    }

    func load() {
        selfRetain = self

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

        let ad = NovvyInterstitialAd(adUnitId: adUnitId, creativeTypes: NovvyAdMobCommon.creativeTypes)
        ad.setImpressionHook { [weak self] in self?.eventDelegate?.reportImpression() }
        ad.delegate = self
        novvyAd = ad
        ad.load()
    }

    // ------------------------------------------------------------------ MediationInterstitialAd

    func present(from viewController: UIViewController) {
        guard let ad = novvyAd, ad.isReady else {
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

    // ------------------------------------------------------------ NovvyInterstitialAdDelegate

    func interstitialAdDidLoad(_ ad: NovvyInterstitialAd) {
        eventDelegate = loadCompletionHandler(self, nil)
    }

    func interstitialAd(_ ad: NovvyInterstitialAd, didFailToLoadWithError error: NovvyError) {
        fail(NovvyAdMobErrorMapping.toAdError(error))
    }

    func interstitialAdDidShow(_ ad: NovvyInterstitialAd) {
        eventDelegate?.willPresentFullScreenView()
    }

    func interstitialAdDidClose(_ ad: NovvyInterstitialAd) {
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
