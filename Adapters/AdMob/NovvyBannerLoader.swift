import Foundation
import GoogleMobileAds
import UIKit
@_spi(Mediation) import NovvyAds

/// One banner slot.
///
/// Three things make banner the only format that is not pure callback translation:
///
/// 1. **The container direction is reversed.** ``NovvyBannerAd`` takes a container view and builds
///    its slot inside it; AdMob wants a view handed back. The bridge is ``wrapper`` — a bare view
///    sized to exactly what AdMob asked for, which the SDK treats as an ordinary host container and
///    AdMob treats as the ad view.
/// 2. **Rotation is switched off** (`refreshIntervalSeconds = 0`). AdMob's `BannerView` re-runs the
///    whole waterfall on its own refresh interval and hands us a brand-new adapter instance each
///    time. A second rotation underneath it would swap creatives that AdMob never counted an
///    impression for — the publisher then sees two irreconcilable impression numbers, which is a
///    standard reason for an ad source to be switched off.
/// 3. **The declared size and the drawn size are not the same number** — see
///    ``NovvyBannerAd/forMediation(adUnitId:requestSize:renderSize:adContainer:refreshIntervalSeconds:)``.
///
/// Same shape as Android's `NovvyBannerLoader`, minus the density arithmetic: `GADAdSize` carries
/// points, and on iOS dp *is* pt.
internal final class NovvyBannerLoader: NSObject, MediationBannerAd, NovvyBannerAdDelegate {

    private let configuration: MediationBannerAdConfiguration
    private let loadCompletionHandler: GADMediationBannerLoadCompletionHandler

    /// The view AdMob mounts, and the container the SDK builds its slot inside. A subclass only so
    /// that detaching from the window can be observed — see ``NovvyBannerLoader/destroy()``.
    private let wrapper = DetachObservingView()

    private var eventDelegate: MediationBannerAdEventDelegate?
    private var novvyAd: NovvyBannerAd?

    /// See ``NovvyRewardedLoader/selfRetain``. Same hazard here: ``NovvyBannerAd/delegate`` is weak,
    /// and nothing retains the loader until it goes back through the completion handler.
    private var selfRetain: NovvyBannerLoader?

    /// Whether ``loadCompletionHandler`` has already been answered. Guards both directions: success
    /// must be reported once, and a later failure must not be reported as a load failure — see
    /// ``bannerAd(_:didFailToLoadWithError:)``.
    private var loadResolved = false
    private var destroyed = false

    init(
        configuration: MediationBannerAdConfiguration,
        completionHandler: @escaping GADMediationBannerLoadCompletionHandler
    ) {
        self.configuration = configuration
        self.loadCompletionHandler = completionHandler
        super.init()
    }

    func load() {
        selfRetain = self

        guard NovvySDK.shared.isInitialized else {
            fail(
                NovvyAdMobErrorMapping.errorNotInitialized,
                "Novvy: NovvySDK.shared.initialize(...) has not been called by the host app"
            )
            return
        }
        guard let adUnitId = NovvyAdMobCommon.adUnitId(from: configuration) else {
            fail(
                NovvyAdMobErrorMapping.errorMissingAdUnitId,
                NovvyAdMobCommon.missingAdUnitIdMessage
            )
            return
        }

        let renderSize = Self.renderSize(for: configuration.adSize)
        wrapper.frame = CGRect(
            origin: .zero,
            size: CGSize(width: CGFloat(renderSize.widthDp), height: CGFloat(renderSize.heightDp))
        )

        let ad = NovvyBannerAd.forMediation(
            adUnitId: adUnitId,
            // Declared to the auction: one of the five tiers, chosen by nearest aspect ratio. The
            // server matches material by ratio (contract §6.4) and stocks it per tier, so a literal
            // 411×50 could be a permanent no-fill if that match turns out to be exact rather than
            // nearest. Normalizing fills either way.
            requestSize: .fromDp(widthDp: renderSize.widthDp, heightDp: renderSize.heightDp),
            // Drawn at what AdMob asked for, because AdMob has already reserved exactly this much of
            // the publisher's layout. Drawing the tier's size instead would be clipped to the
            // reserved box, and a clipped creative never passes the >50% viewability gate — a slot
            // that can never bill. The ratio difference is absorbed by the banner host's
            // unconditional cover scaling.
            renderSize: renderSize,
            adContainer: wrapper,
            refreshIntervalSeconds: 0
        )
        // Fires off the SDK's viewability gate, not off mount — see ``NovvyRewardedLoader/load()``.
        ad.setImpressionHook { [weak self] in self?.eventDelegate?.reportImpression() }
        ad.delegate = self
        novvyAd = ad
        wrapper.onDetachedFromWindow = { [weak self] in self?.handleDetach() }
        ad.load()
    }

    /// What the slot is drawn at, in dp (= pt).
    ///
    /// `cgSize(for:)` because `AdSize` is opaque — the header is explicit that its fields must not
    /// be read directly.
    ///
    /// **The non-positive fallback is load-bearing, not defensive.** ``NovvyAdSize`` clamps a
    /// negative dimension to `0` rather than throwing, and the request side reads `0` as "size not
    /// declared" and falls back to a default — but the *render* side reads the same `0` as a
    /// zero-sized slot, which draws nothing at all and can never produce an impression. AdMob does
    /// hand out sizes like that: a fluid ad size, and an anchored adaptive size that has not been
    /// resolved against a real width yet. So an explicit tier fallback has to happen here, at the
    /// mediation entry point.
    private static func renderSize(for adSize: AdSize) -> NovvyAdSize {
        let size = cgSize(for: adSize)
        let widthDp = Int(size.width.rounded())
        let heightDp = Int(size.height.rounded())
        guard widthDp > 0, heightDp > 0 else { return NovvyBannerSize.standard.adSize }
        return NovvyAdSize(widthDp: widthDp, heightDp: heightDp)
    }

    // -------------------------------------------------------------------------- MediationBannerAd

    var view: UIView { wrapper }

    // ----------------------------------------------------------------------- NovvyBannerAdDelegate

    func bannerAdDidLoad(_ ad: NovvyBannerAd) {
        guard !loadResolved else { return }
        loadResolved = true
        eventDelegate = loadCompletionHandler(self, nil)
        // Google holds this object as the MediationBannerAd from here on, so the temporary
        // self-reference has done its job.
        selfRetain = nil
    }

    /// Reported to AdMob **only before the first fill**.
    ///
    /// This callback means "one prefetch failed; whatever is on screen stays and the SDK will retry
    /// with a backoff", so on a rotating slot it can fire repeatedly while the banner is displaying
    /// perfectly well. With rotation switched off the two meanings happen to coincide, but the guard
    /// is written explicitly so that turning rotation back on some day cannot quietly start
    /// reporting healthy slots as failures.
    ///
    /// It is also the convergence point for the one asymmetry the iOS SDK has here: with rotation
    /// off, the first fill is attempted **up to 3 times** before giving up, while an adapter may
    /// report a failure to AdMob exactly once. The guard makes the first report the only report; the
    /// SDK's remaining attempts simply have nowhere to go, which is the correct outcome — by then
    /// AdMob has already moved to the next waterfall layer.
    func bannerAd(_ ad: NovvyBannerAd, didFailToLoadWithError error: NovvyError) {
        guard !loadResolved else { return }
        loadResolved = true
        _ = loadCompletionHandler(nil, NovvyAdMobErrorMapping.toAdError(error))
        destroy()
    }

    func bannerAdDidClick(_ ad: NovvyBannerAd) {
        // Banner is the only Novvy delegate carrying a click callback — an asymmetry argued for its
        // own reasons (a permanently resident slot gives the host no lifecycle event to infer
        // engagement from) that happens to be exactly what a mediation needs.
        eventDelegate?.reportClick()
    }

    // ---------------------------------------------------------------------------------- teardown

    /// The mediation banner interface has no destroy callback, so the view leaving the window is the
    /// only signal that the slot is finished.
    ///
    /// The check is deferred by one main-queue turn rather than run inline: a view moved within a
    /// hierarchy (AdMob swapping in the next refresh's view, a recycled cell) leaves and re-enters
    /// the window within the same runloop turn, and tearing the ad down on the leaving half of that
    /// would destroy a live banner.
    private func handleDetach() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.wrapper.window == nil else { return }
            self.destroy()
        }
    }

    private func destroy() {
        guard !destroyed else { return }
        destroyed = true
        // Releases the creative and removes the SDK's own slot from `wrapper`. It does not touch
        // `wrapper` itself, which is AdMob's to detach.
        novvyAd?.destroy()
        novvyAd = nil
        eventDelegate = nil
        selfRetain = nil
    }

    private func fail(_ code: Int, _ message: String) {
        guard !loadResolved else { return }
        loadResolved = true
        _ = loadCompletionHandler(nil, NovvyAdMobErrorMapping.adError(code, message))
        selfRetain = nil
    }
}

/// A plain container that reports leaving the window.
///
/// `didMoveToWindow` is the only hook for this; there is no attach-state listener on UIKit the way
/// there is on Android. Kept as a nested-scope helper rather than a general utility because the one
/// thing it exists for is ``NovvyBannerLoader``'s teardown.
private final class DetachObservingView: UIView {
    var onDetachedFromWindow: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { onDetachedFromWindow?() }
    }
}
