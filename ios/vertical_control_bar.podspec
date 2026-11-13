Pod::Spec.new do |s|
  s.name             = 'vertical_control_bar'
  s.version          = '1.0.0'
  s.summary          = 'iPhone Duo vertical control bar for Flutter apps.'
  s.description      = <<-DESC
Reports the usable range of the iPhone Duo vertical bar (UIView.LayoutRegion.bar)
to Flutter. The iOS 27.1 API is called through the Objective-C runtime, so the
pod also builds with older SDKs.
                       DESC
  s.homepage         = 'https://github.com/buyandship/vertical_control_bar'
  s.license          = { :type => 'Proprietary' }
  s.author           = 'Buyandship'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
  s.swift_version = '5.0'
end
