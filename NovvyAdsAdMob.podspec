Pod::Spec.new do |s|
  s.name         = 'NovvyAdsAdMob'
  s.version      = '1.0.0-beta.14'
  s.summary      = 'NovvyAds AdMob mediation adapter.'
  s.description  = 'AdMob custom event adapter that bridges Google Mobile Ads SDK to NovvyAds inventory.'
  s.homepage     = 'https://github.com/NovvyAI/novvy-ads-cocoapods'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'NovvyAI' => 'dev@novvy.ai' }
  s.platform     = :ios, '13.0'
  s.swift_versions = ['5.0']

  s.source = {
    :git => 'https://github.com/NovvyAI/novvy-ads-cocoapods.git',
    :tag => "v#{s.version}"
  }

  s.source_files = 'Adapters/AdMob/**/*.swift'

  s.dependency 'NovvyAds', s.version.to_s
  s.dependency 'Google-Mobile-Ads-SDK', '~> 12.0'
end
