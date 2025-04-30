Pod::Spec.new do |s|
    s.name             = 'es-cast-client-ios'
    s.version          = '0.1.5'
    s.summary          = 'A library for integrating es-cast functionality into iOS apps.'

    s.description      = <<-DESC
    es-cast-client-ios is a library that enables iOS app developers to easily integrate es-cast functionality into their applications. It provides a simple and efficient way to interact with es-cast features, such as screen casting and remote control.
    DESC

    s.homepage         = 'https://github.com/hanliang-tech/es-cast-client-ios'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'birdmichael' => 'birdmichael126@gmail.com' }
    s.source           = { :git => 'https://github.com/hanliang-tech/es-cast-client-ios.git', :tag => s.version.to_s }

    s.ios.deployment_target = '12.0'
    s.swift_version = '5.0'

    s.vendored_frameworks = 'Proxy.xcframework'

    s.source_files = 'Sources/es-cast-client-ios/**/*'
end
