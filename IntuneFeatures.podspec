Pod::Spec.new do |s|
  s.name         = "IntuneFeatures"
  s.version      = "0.3.0"
  s.summary      = "Audio feature extraction"
  s.homepage     = "https://github.com/venturemedia/intune-features"
  s.license      = "Proprietary"
  s.author       = { "Alejandro Isaza" => "aisaza@venturemedia.com" }
  
  s.ios.deployment_target = "8.4"
  s.osx.deployment_target = "10.11"

  s.source = { git: "https://github.com/venturemedia/intune-features.git", tag: s.version }
  s.source_files = "Sources/**/*.swift"
  s.resource_bundle = { 'NoteCurves' => 'Resources/note_curves.h5' }

  s.dependency 'HDF5Kit', '~> 0.1'
  s.dependency 'Peak/MIDI', '~> 1.2'
  s.dependency 'Upsurge', '~> 0.7'
end
