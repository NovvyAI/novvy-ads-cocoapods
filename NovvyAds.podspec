Pod::Spec.new do |s|
  s.name         = 'NovvyAds'
  s.version      = '1.0.0-beta.12'
  s.summary      = 'NovvyAds iOS SDK for programmatic advertising.'
  s.description  = 'NovvyAds SDK provides interstitial, rewarded, banner, and feed ad formats for iOS apps.'
  s.homepage     = 'https://github.com/NovvyAI/novvy-ads-cocoapods'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'NovvyAI' => 'dev@novvy.ai' }
  s.platform     = :ios, '13.0'
  s.swift_versions = ['5.0']

  s.source = {
    :http => "https://github.com/NovvyAI/novvy-ads-cocoapods/releases/download/v#{s.version}/NovvyAds.xcframework.zip"
  }

  s.default_subspecs = ['Core']

  s.subspec 'Core' do |core|
    core.vendored_frameworks = 'NovvyAds.xcframework'
  end
end
