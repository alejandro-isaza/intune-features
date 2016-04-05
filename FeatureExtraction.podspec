Pod::Spec.new do |s|
  s.name         = "FeatureExtraction"
  s.version      = "0.2.0"
  s.summary      = "Audio feature extraction"
  s.homepage     = "https://github.com/venturemedia/audio-features"
  s.license      = "Proprietary"
  s.author       = { "Alejandro Isaza" => "aisaza@venturemedia.com" }
  
  s.ios.deployment_target = "8.4"
  s.osx.deployment_target = "10.11"

  s.source       = { git: "https://github.com/venturemedia/audio-features.git", tag: s.version }
  s.source_files  = "FeatureExtraction/FeatureExtraction/*.swift", "FeatureExtraction/FeatureExtraction/**/*.swift"

  s.dependency "Upsurge", '~> 0.1'
  s.dependency "HDF5Kit", '~> 0.1'
  s.dependency "Peak/MIDI", '~> 1.2'
end
