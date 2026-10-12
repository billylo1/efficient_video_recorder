#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint efficient_video_recorder.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'efficient_video_recorder'
  s.version          = '0.1.0'
  s.summary          = 'High-efficiency, low-power camera video recorder for Flutter (CameraX & AVFoundation).'
  s.description      = <<-DESC
High-efficiency video recording plugin optimized for low battery consumption and zero thermal throttling, using CameraX SurfaceView hardware overlays on Android and AVFoundation on iOS.
                       DESC
  s.homepage         = 'https://github.com/billylo1/efficient_video_recorder'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Evergreen Labs' => 'team@evergreen-labs.org' }
  s.source           = { :path => '.' }
  s.source_files = 'efficient_video_recorder/Sources/efficient_video_recorder/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'efficient_video_recorder_privacy' => ['efficient_video_recorder/Sources/efficient_video_recorder/PrivacyInfo.xcprivacy']}
end
