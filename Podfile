use_frameworks!
inhibit_all_warnings!

platform :osx, "10.10"
xcodeproj 'FeatureExtraction/FeatureExtraction'
workspace 'IntuneLab'

link_with "FeatureExtraction", "FeatureExtractionTests", "CompileFeatures"
pod "Upsurge", :git => "https://github.com/aleph7/Upsurge.git", :branch => "master"
pod "HDF5Kit"
pod "BrainCore"
pod "Peak"
pod "PlotKit"
