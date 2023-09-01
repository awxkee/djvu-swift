Pod::Spec.new do |s|
    s.name             = 'djvu'
    s.version          = '1.0.6'
    s.summary          = 'DJVU parser for iOS and MacOS'
    s.description      = 'Provides support for DJVU files in iOS and MacOS'
    s.homepage         = 'https://github.com/awxkee/djvu-swift'
    s.license          = { :type => 'CC0', :file => 'LICENSE' }
    s.author           = { 'username' => 'radzivon.bartoshyk@proton.me' }
    s.source           = { :git => 'https://github.com/awxkee/djvu-swift.git', :tag => "#{s.version}" }
    s.ios.deployment_target = '11.0'
    s.osx.deployment_target = '11.0'
    s.source_files = 'Sources/djvu/*.swift', "Sources/libdjvu/*.{swift,h,m,cpp,mm,hpp}", 'Sources/libdjvu/include/DjvuParser.h', 'Sources/libdjvu/include/config.h'
    s.swift_version = ["5.3", "5.4", "5.5"]
    s.frameworks = "Foundation", "CoreGraphics", "Accelerate"
    s.public_header_files = 'Sources/libdjvu/include/DjvuParser.h'
    s.project_header_files = 'Sources/libdjvu/include/config.h'
    s.pod_target_xcconfig = {
        'OTHER_CXXFLAGS' => '$(inherited) -std=c++20',
        'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) HAVE_PTHREAD=1 NS_BLOCK_ASSERTIONS=1 HAVE_CONFIG_H=1'
    }
    s.libraries = 'c++'
    s.requires_arc = true
end