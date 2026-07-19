import Foundation
import UIKit
import NovvyAds
import GoogleMobileAds

class NovvyAdMobRewardedHandler: NSObject, MediationRewardedAd, NovvyRewardedAdDelegate {

    private let novvyAd: NovvyRewardedAd
    private var loadCompletionHandler: GADMediationRewardedLoadCompletionHandler?
    private var eventDelegate: MediationRewardedAdEventDelegate?

    init(adUnitId: String) {
        self.novvyAd = NovvyRewardedAd(adUnitId: adUnitId)
        super.init()
        self.novvyAd.bidSource = "admob"
        self.novvyAd.delegate = self
    }

    func load(completionHandler: @escaping GADMediationRewardedLoadCompletionHandler) {
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

    func rewardedAdDidLoad(_ ad: NovvyRewardedAd) {
        eventDelegate = loadCompletionHandler?(self, nil)
        loadCompletionHandler = nil
    }

    func rewardedAd(_ ad: NovvyRewardedAd, didFailToLoadWithError error: NovvyError) {
        let nsError = NSError(domain: "ai.novvy.admob", code: 2, userInfo: [
            NSLocalizedDescriptionKey: error.localizedDescription
        ])
        _ = loadCompletionHandler?(nil, nsError)
        loadCompletionHandler = nil
    }

    func rewardedAdDidShow(_ ad: NovvyRewardedAd) {
        eventDelegate?.willPresentFullScreenView()
        eventDelegate?.didStartVideo()
        eventDelegate?.reportImpression()
    }

    func rewardedAdDidClose(_ ad: NovvyRewardedAd) {
        eventDelegate?.didEndVideo()
        eventDelegate?.willDismissFullScreenView()
        eventDelegate?.didDismissFullScreenView()
    }

    func rewardedAd(_ ad: NovvyRewardedAd, didEarnReward reward: NovvyReward) {
        eventDelegate?.didRewardUser()
    }
}
