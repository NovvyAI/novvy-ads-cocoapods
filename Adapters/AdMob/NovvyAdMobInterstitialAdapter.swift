import Foundation
import UIKit
import NovvyAds
import GoogleMobileAds

public class NovvyAdMobMediationAdapter: GADMediationAdapter {

    public static func adapterVersion() -> GADVersionNumber {
        GADVersionNumber(majorVersion: 1, minorVersion: 0, patchVersion: 0)
    }

    public static func adSDKVersion() -> GADVersionNumber {
        GADVersionNumber(majorVersion: 1, minorVersion: 0, patchVersion: 0)
    }

    public static func networkExtrasClass() -> (any GADAdNetworkExtras.Type)? {
        nil
    }

    public override static func setUpWith(
        _ configuration: GADMediationServerConfiguration,
        completionHandler: @escaping GADMediationAdapterSetUpCompletionBlock
    ) {
        completionHandler(nil)
    }

    public override func loadInterstitial(
        for adConfiguration: GADMediationInterstitialAdConfiguration,
        completionHandler: @escaping GADMediationInterstitialLoadCompletionHandler
    ) {
        let adUnitId = adConfiguration.credentials.settings["parameter"] as? String ?? ""
        guard !adUnitId.isEmpty else {
            let error = NSError(domain: "ai.novvy.admob", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Missing Ad Unit ID in AdMob custom event parameter"
            ])
            _ = completionHandler(nil, error)
            return
        }

        let handler = NovvyAdMobInterstitialHandler(adUnitId: adUnitId)
        handler.load(completionHandler: completionHandler)
    }

    public override func loadRewardedAd(
        for adConfiguration: GADMediationRewardedAdConfiguration,
        completionHandler: @escaping GADMediationRewardedLoadCompletionHandler
    ) {
        let adUnitId = adConfiguration.credentials.settings["parameter"] as? String ?? ""
        guard !adUnitId.isEmpty else {
            let error = NSError(domain: "ai.novvy.admob", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Missing Ad Unit ID in AdMob custom event parameter"
            ])
            _ = completionHandler(nil, error)
            return
        }

        let handler = NovvyAdMobRewardedHandler(adUnitId: adUnitId)
        handler.load(completionHandler: completionHandler)
    }
}

class NovvyAdMobInterstitialHandler: NSObject, GADMediationInterstitialAd, NovvyInterstitialAdDelegate {

    private let novvyAd: NovvyInterstitialAd
    private var loadCompletionHandler: GADMediationInterstitialLoadCompletionHandler?
    private var eventDelegate: GADMediationInterstitialAdEventDelegate?

    init(adUnitId: String) {
        self.novvyAd = NovvyInterstitialAd(adUnitId: adUnitId)
        super.init()
        self.novvyAd.delegate = self
    }

    func load(completionHandler: @escaping GADMediationInterstitialLoadCompletionHandler) {
        self.loadCompletionHandler = completionHandler
        novvyAd.load()
    }

    func present(from viewController: UIViewController) {
        if novvyAd.isReady {
            novvyAd.show(from: viewController)
        } else {
            let error = NSError(domain: "ai.novvy.admob", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Ad not ready"
            ])
            eventDelegate?.didFailToPresentWithError(error)
        }
    }

    func interstitialAdDidLoad(_ ad: NovvyInterstitialAd) {
        eventDelegate = loadCompletionHandler?(self, nil)
        loadCompletionHandler = nil
    }

    func interstitialAd(_ ad: NovvyInterstitialAd, didFailToLoadWithError error: NovvyError) {
        let nsError = NSError(domain: "ai.novvy.admob", code: 2, userInfo: [
            NSLocalizedDescriptionKey: error.localizedDescription
        ])
        _ = loadCompletionHandler?(nil, nsError)
        loadCompletionHandler = nil
    }

    func interstitialAdDidShow(_ ad: NovvyInterstitialAd) {
        eventDelegate?.willPresentFullScreenView()
        eventDelegate?.reportImpression()
    }

    func interstitialAdDidClose(_ ad: NovvyInterstitialAd) {
        eventDelegate?.willDismissFullScreenView()
        eventDelegate?.didDismissFullScreenView()
    }

    func interstitialAdDidClick(_ ad: NovvyInterstitialAd) {
        eventDelegate?.reportClick()
    }
}
