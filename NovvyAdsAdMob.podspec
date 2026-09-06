# The two values a release edits. Composed rather than written out as a single literal, so that
# the core version the adapter pins and the core version encoded in its own version number are the
# same string by construction — deriving one from the other by parsing is what goes wrong here.
# (`1.2.0-beta.1` splits as core `1.2.0-beta` + revision `1` just as readily as it splits the way
# you meant, and both are plausible enough to ship.)
#
# Mirrors Android's NovvyAdMobAdapter, which composes the same two values out of gradle.properties
# as `${sdk.version}.${mediation.adapter.revision}`.
novvy_ads_version = '1.2.0-beta.1'

# Bumped when the adapter changes on its own; reset to 0 whenever novvy_ads_version moves.
#
# Resetting is not optional. The dependency below is an exact pin, so every NovvyAds release needs
# a matching adapter release even when no adapter code changed — cut it as `<new core>.0`.
adapter_revision = 0

Pod::Spec.new do |s|
  s.name         = 'NovvyAdsAdMob'

  # `<NovvyAds version>.<adapter revision>` — the shape every AdMob mediation adapter ships
  # (GoogleMobileAdsMediationVungle 7.4.1.0, AppLovin 13.0.1.0). A publisher can read which core
  # an adapter goes with straight off the version number, and an adapter-only fix does not have to
  # move the SDK's version. Prereleases keep the shape: NovvyAds 1.2.0-beta.1 -> 1.2.0-beta.1.0.
  s.version      = "#{novvy_ads_version}.#{adapter_revision}"

  s.summary      = 'NovvyAds AdMob mediation adapter.'
  s.description  = 'AdMob custom event adapter that bridges Google Mobile Ads SDK to NovvyAds inventory.'
  s.homepage     = 'https://github.com/NovvyAI/novvy-ads-cocoapods'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'NovvyAI' => 'dev@novvy.ai' }
  s.platform     = :ios, '13.0'
  s.swift_versions = ['5.0']

  # Prefixed tag, because the two pods no longer share a version and so can no longer share a tag.
  # NovvyAds keeps `v<version>`; the adapter gets its own namespace so an adapter-only release has
  # somewhere to point. Tag v1.1.5 shows what the shared scheme cost: it was cut while the adapter
  # was deleted from main, so `v1.1.5/NovvyAdsAdMob.podspec` is a 404.
  s.source = {
    :git => 'https://github.com/NovvyAI/novvy-ads-cocoapods.git',
    :tag => "admob-v#{s.version}"
  }

  # A **source** pod, unlike NovvyAds itself: the adapter has to link GoogleMobileAds, and that
  # framework must not end up inside NovvyAds.xcframework — publishers who do not use AdMob would
  # be forced to carry it.
  s.source_files = 'Adapters/AdMob/**/*.swift'

  # Exact pin, not `~>`. Publishers install both pods by `:podspec` URL (see README), which means
  # they name a tag per pod and nothing stops them naming a mismatched pair; this pin is what turns
  # that into a `pod install` failure instead of a runtime surprise.
  #
  # Note this file is fetched standalone from raw.githubusercontent.com in that setup — it cannot
  # read NovvyAds.podspec off disk to discover the core version, hence the local above.
  s.dependency 'NovvyAds', novvy_ads_version
  s.dependency 'Google-Mobile-Ads-SDK', '~> 12.0'
end
