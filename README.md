# NovvyAds iOS SDK

NovvyAds iOS SDK provides programmatic advertising capabilities for iOS apps, supporting Interstitial, Rewarded, Banner, and Feed ad formats.

## Requirements

- iOS 13.0+
- Swift 5.0+
- Xcode 14.0+

## Installation

Install NovvyAds via CocoaPods

### NovvyAds SDK Only (without AdMob)

Add the following to your `Podfile`:

```ruby
source 'https://github.com/NovvyAI/novvy-ads-cocoapods.git'

pod 'NovvyAds', '~> 1.0.0-beta.x'
```

This pulls in `NovvyAds/Core` by default, which contains the core SDK framework.

Then run:

```bash
pod install
```

### With AdMob Mediation

If you want to use NovvyAds as a mediation source through Google AdMob, add the `AdMob` subspec:

```ruby
source 'https://github.com/NovvyAI/novvy-ads-cocoapods.git'

pod 'NovvyAds', '~> 1.0.0-beta.x'
pod 'NovvyAds/AdMob', '~> 1.0.0-beta.x'
```

This automatically brings in the following dependencies:

- `NovvyAds/Core` — NovvyAds core SDK
- `Google-Mobile-Ads-SDK` (~> 12.0) — Google AdMob SDK

Then run:

```bash
pod install
```

#### AdMob Configuration

1. **Info.plist**

   Add your AdMob App ID to your project's `Info.plist`:

   ```xml
   <key>GADApplicationIdentifier</key>
   <string>your-admob-app-id</string>
   ```

2. **Initialize the Google Mobile Ads SDK**

   In your `AppDelegate`:

   ```swift
   import GoogleMobileAds

   func application(
       _ application: UIApplication,
       didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
   ) -> Bool {
       MobileAds.shared.start()
       return true
   }
   ```

3. **Set Up Mediation in the AdMob Console**

   In the [AdMob console](https://apps.admob.com), add a Custom Event to your ad units:

   - **Class Name**: `NovvyAdMobMediationAdapter`
   - **Parameter**: Your NovvyAds ad unit ID

   The AdMob mediation adapter currently supports:
   - Interstitial ads
   - Rewarded ads

## License

NovvyAds is released under the MIT License. See [LICENSE](LICENSE) for details.