use_frameworks!

target 'IntuneFeatures.OSX' do
  platform :osx, '10.11'
  target 'IntuneFeaturesTests.OSX'

  pod 'HDF5Kit', '~> 0.1', inhibit_warnings: true
  pod 'Peak/MIDI', '~> 1.2'
  pod 'Upsurge', '~> 0.7.1'
end

target 'IntuneFeatures.iOS' do
  platform :ios, '8.4'
  target 'IntuneFeaturesTests.iOS'

  pod 'HDF5Kit', '~> 0.1', inhibit_warnings: true
  pod 'Peak/MIDI', '~> 1.2'
  pod 'Upsurge', '~> 0.7.1'
end

target :CompileFeatures do
  platform :osx, '10.11'

  pod 'HDF5Kit', '~> 0.1', inhibit_warnings: true
  pod 'Peak/AudioFile', '~> 1.2'
  pod 'Peak/MIDI', '~> 1.2'
  pod 'Upsurge', '~> 0.7.1'
end
