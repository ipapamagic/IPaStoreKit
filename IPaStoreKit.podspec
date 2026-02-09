#
# Be sure to run `pod lib lint IPaStoreKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'IPaStoreKit'
  s.version          = '5.0.0'
  s.summary          = 'Modern Swift wrapper for StoreKit 2 with async/await support.'
  s.swift_version    = '5.6'
# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
IPaStoreKit is a modern StoreKit 2 wrapper with async/await APIs, product caching, and automatic transaction verification.
Supports iOS 15+ / macOS 12+ and integrates with IPaLog for unified logging.
                       DESC

  s.homepage         = 'https://github.com/ipapamagic/IPaStoreKit'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'ipapamagic@gmail.com' => 'ipapamagic@gmail.com' }
  s.source           = { :git => 'https://github.com/ipapamagic/IPaStoreKit.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'

  s.source_files = 'Sources/IPaStoreKit/**/*'
#  s.ios.vendored_frameworks = "IPaStoreKit/openssl.framework"
  #s.osx.source_files = 'IPaStoreKit/Classes/**/*'
  #s.osx.vendored_frameworks = "IPaStoreKit/openssl.framework"
  # s.resource_bundles = {
  #   'IPaStoreKit' => ['IPaStoreKit/Assets/*.png']
  # }
  # s.resources  = "IPaStoreKit/Assets/AppleIncRootCertificate.cer"
  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
#  s.dependency 'GRKOpenSSLFramework'
#  s.dependency 'OpenSSL-Universal'
    s.dependency 'IPaLog', '~> 3.1.0'
end
