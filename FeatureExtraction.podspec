Pod::Spec.new do |s|
  s.name         = "FeatureExtraction"
  s.version      = "0.1.0"
  s.summary      = "Audio feature extraction"
  s.homepage     = "https://github.com/venturemedia/audio-features"
  s.license      = "Proprietary"
  s.author       = { "Alejandro Isaza" => "aisaza@venturemedia.com" }
  
  s.ios.deployment_target = "8.4"
  s.osx.deployment_target = "10.11"

  s.source       = { git: "https://github.com/venturemedia/audio-features.git", tag: s.version }
  s.source_files  = "FeatureExtraction/FeatureExtraction/*.swift", "FeatureExtraction/FeatureExtraction/**/*.swift"

  s.dependency "Upsurge", '~> 0.6'
  s.dependency "HDF5Kit", '~> 0.0'
  s.dependency "Peak/MIDI", '~> 1.2'
end
