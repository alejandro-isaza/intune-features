use_frameworks!
inhibit_all_warnings!

xcodeproj 'FeatureExtraction/FeatureExtraction'
workspace 'IntuneLab'



target 'OSX' do
  platform :osx, '10.10'
  link_with "FeatureExtraction", "FeatureExtractionTests", "CompileFeatures"

  pod "Upsurge", :git => "https://github.com/aleph7/Upsurge.git", :branch => "master"
  pod "HDF5Kit", :git => "https://github.com/aleph7/HDF5Kit.git", :branch => "master"
  pod "BrainCore"
  pod "Peak"
  pod "PlotKit"
end

target 'iOS' do
  platform :ios, '8.4'
  link_with "NetEval"
  
  pod "Upsurge", :git => "https://github.com/aleph7/Upsurge.git", :branch => "master"
  pod "HDF5Kit", :git => "https://github.com/aleph7/HDF5Kit.git", :branch => "master"
  pod "BrainCore"
  pod "Peak"
end
