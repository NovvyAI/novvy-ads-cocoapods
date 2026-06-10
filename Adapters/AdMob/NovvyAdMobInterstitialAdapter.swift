import Foundation
import UIKit
import NovvyAds
import GoogleMobileAds

@objc(NovvyAdMobMediationAdapter)
public class NovvyAdMobMediationAdapter: NSObject, MediationAdapter {

    private var interstitialHandler: NovvyAdMobInterstitialHandler?
    private var rewardedHandler: NovvyAdMobRewardedHandler?

    public required override init() {
        super.init()
    }

    public static func adapterVersion() -> VersionNumber {
        VersionNumber(majorVersion: 1, minorVersion: 0, patchVersion: 0)
    }

    public static func adSDKVersion() -> VersionNumber {
        VersionNumber(majorVersion: 1, minorVersion: 0, patchVersion: 0)
    }

    public static func networkExtrasClass() -> (any AdNetworkExtras.Type)? {
        nil
    }

    public static func setUp(
        with configuration: MediationServerConfiguration,
        completionHandler: @escaping GADMediationAdapterSetUpCompletionBlock
    ) {
        completionHandler(nil)
    }

    private struct ServerParams {
        let adUnitId: String
        let bidFloor: Double
    }

    private func parseServerParams(from parameter: String?) -> ServerParams {
        guard let parameter = parameter, !parameter.isEmpty else { return ServerParams(adUnitId: "", bidFloor: 0) }
        if let data = parameter.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let adUnitId = json["adUnitId"] as? String ?? ""
            let bidFloor = json["bidFloor"] as? Double ?? 0
            return ServerParams(adUnitId: adUnitId, bidFloor: bidFloor)
        }
        return ServerParams(adUnitId: parameter, bidFloor: 0)
    }

    public func loadInterstitial(
        for adConfiguration: MediationInterstitialAdConfiguration,
        completionHandler: @escaping GADMediationInterstitialLoadCompletionHandler
    ) {
        let params = parseServerParams(from: adConfiguration.credentials.settings["parameter"] as? String)
        guard !params.adUnitId.isEmpty else {
            let error = NSError(domain: "ai.novvy.admob", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Missing Ad Unit ID in AdMob custom event parameter"
            ])
            _ = completionHandler(nil, error)
            return
        }

        let handler = NovvyAdMobInterstitialHandler(adUnitId: params.adUnitId, bidFloor: params.bidFloor)
        self.interstitialHandler = handler
        handler.load(completionHandler: completionHandler)
    }

    public func loadRewardedAd(
        for adConfiguration: MediationRewardedAdConfiguration,
        completionHandler: @escaping GADMediationRewardedLoadCompletionHandler
    ) {
        let params = parseServerParams(from: adConfiguration.credentials.settings["parameter"] as? String)
        guard !params.adUnitId.isEmpty else {
            let error = NSError(domain: "ai.novvy.admob", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Missing Ad Unit ID in AdMob custom event parameter"
            ])
            _ = completionHandler(nil, error)
            return
        }

        let handler = NovvyAdMobRewardedHandler(adUnitId: params.adUnitId, bidFloor: params.bidFloor)
        self.rewardedHandler = handler
        handler.load(completionHandler: completionHandler)
    }
}

class NovvyAdMobInterstitialHandler: NSObject, MediationInterstitialAd, NovvyInterstitialAdDelegate {

    private let novvyAd: NovvyInterstitialAd
    private var loadCompletionHandler: GADMediationInterstitialLoadCompletionHandler?
    private var eventDelegate: MediationInterstitialAdEventDelegate?

    init(adUnitId: String, bidFloor: Double) {
        self.novvyAd = NovvyInterstitialAd(adUnitId: adUnitId)
        super.init()
        if bidFloor > 0 { self.novvyAd.bidFloor = bidFloor }
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
