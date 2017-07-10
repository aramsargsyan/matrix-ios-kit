Pod::Spec.new do |s|

  s.name         = "MatrixKit"
  s.version      = "0.5.2"
  s.summary      = "The Matrix reusable UI library for iOS based on MatrixSDK."

  s.description  = <<-DESC
					Matrix Kit provides basic reusable interfaces to ease building of apps compatible with Matrix (https://www.matrix.org).
                   DESC

  s.homepage     = "https://www.matrix.org"

  s.license      = { :type => "Apache License, Version 2.0", :file => "LICENSE" }

  s.author             = { "matrix.org" => "support@matrix.org" }
  s.social_media_url   = "http://twitter.com/matrixdotorg"

  s.platform     = :ios, "8.0"

  s.source       = { :git => "https://github.com/matrix-org/matrix-ios-kit.git", :tag => "v0.5.2" }
  s.resources	 = "MatrixKit/**/*.{xib}"
  s.resource_bundles = { 'MatrixKit' => ['MatrixKit/Assets/MatrixKitAssets.bundle/**'] }

  s.requires_arc  = true

  s.dependency 'HPGrowingTextView', '~> 1.1'
  s.dependency 'libPhoneNumber-iOS', '~> 0.9.10'
  s.dependency 'cmark', '~> 0.24.1'

  s.default_subspec = 'Core'

  s.subspec 'Core' do |core|
    #Use the matching subspec of MatrixSDK
    core.dependency 'MatrixSDK/Core'
    core.dependency 'DTCoreText'
    
    core.source_files = "MatrixKit", "MatrixKit/**/*.{h,m}"
  end

  s.subspec 'AppExtension' do |ext|
    ext.dependency 'MatrixKit/Core'

    #Use the extension-compaitable subspecs of MatrixSDK and DTCoreText
    ext.dependency 'MatrixSDK/AppExtension'
    ext.dependency 'DTCoreText/Extension'

    #For app extensions, disabling code paths using unavailable API
    ext.pod_target_xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => 'MXK_APP_EXTENSIONS=1' }
  end

end
