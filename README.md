# NovvyAds iOS SDK

NovvyAds iOS SDK provides programmatic advertising capabilities for iOS apps, supporting Interstitial, Rewarded, Banner, and Feed ad formats.

## Requirements

- iOS 13.0+
- Swift 5.0+
- Xcode 14.0+

## Installation

Pods are installed by pointing CocoaPods at a podspec URL. The git tag in the URL *is* the version
selector — there is no spec repo to search, so a `:podspec` line takes no version requirement and
CocoaPods will reject one if you add it.

### NovvyAds only

```ruby
target 'YourApp' do
  pod 'NovvyAds', :podspec => 'https://raw.githubusercontent.com/NovvyAI/novvy-ads-cocoapods/v1.2.0-beta.1/NovvyAds.podspec'
end
```

### With AdMob mediation

```ruby
target 'YourApp' do
  # Required. NovvyAdsAdMob ships as source and links two vendored frameworks (NovvyAds and, since
  # GMA 12.x, GoogleMobileAds); under the default dynamic `use_frameworks!` CocoaPods refuses to
  # build a dynamic framework around them. Static linkage also puts `-ObjC` in OTHER_LDFLAGS, which
  # is what keeps `NovvyAdMobMediationAdapter` in the final binary — AdMob instantiates it by name
  # at runtime, so nothing references it at compile time and the linker would otherwise drop it.
  # The symptom of getting this wrong is not a build error; it is a silent no-fill.
  use_frameworks! :linkage => :static

  pod 'NovvyAds',      :podspec => 'https://raw.githubusercontent.com/NovvyAI/novvy-ads-cocoapods/v1.2.0-beta.1/NovvyAds.podspec'
  pod 'NovvyAdsAdMob', :podspec => 'https://raw.githubusercontent.com/NovvyAI/novvy-ads-cocoapods/admob-v1.2.0-beta.1.0/NovvyAdsAdMob.podspec'
end
```

Both lines are required. `NovvyAdsAdMob` declares an exact dependency on `NovvyAds`, and without a
spec repo to resolve it from, that dependency is only satisfiable by a `NovvyAds` line of your own.

The two tags have to be a matching pair (see Versioning below). They will not silently disagree:
the adapter pins the exact core version it was built against, so a mismatched pair fails during
`pod install` rather than at runtime.

Then run:

```bash
pod install
```

To move to a new version, edit the URLs and run `pod update NovvyAds NovvyAdsAdMob`. A plain
`pod install` will keep resolving to whatever `Podfile.lock` already records. Note that
`pod outdated` does not report updates for pods installed this way — watch the releases page.

## Versioning

`NovvyAds` uses three segments. `NovvyAdsAdMob` appends a fourth:

```text
NovvyAdsAdMob 1.2.0.3
              └───┘ └ adapter revision
                └ the NovvyAds version this adapter is built against
```

This is the shape AdMob mediation adapters conventionally ship in, and the same one the Android
NovvyAdMobAdapter uses. It means the version number alone tells you which core an adapter pairs
with, and an adapter-only fix does not have to move the SDK's version number.

The core version moving resets the revision to `0`; an adapter-only change bumps it. Because the
dependency is an exact pin, every `NovvyAds` release gets a matching adapter release even when no
adapter code changed.

| NovvyAds tag | NovvyAdsAdMob tag | why |
| --- | --- | --- |
| `v1.2.0-beta.1` | `admob-v1.2.0-beta.1.0` | first adapter release for core 1.2.0-beta.1 |
| `v1.2.0-beta.1` | `admob-v1.2.0-beta.1.1` | adapter fix, core unchanged |
| `v1.2.0-beta.2` | `admob-v1.2.0-beta.2.0` | core released; revision resets |
| `v1.2.0` | `admob-v1.2.0.0` | 1.2.0 ships |
| `v1.2.0` | `admob-v1.2.0.1` | adapter fix on the released core |

## License

NovvyAds is released under the MIT License. See [LICENSE](LICENSE) for details.
