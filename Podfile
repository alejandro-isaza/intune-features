use_frameworks!

abstract_target 'osx' do
  platform :osx, '10.11'
  target 'IntuneFeatures.OSX'
  target 'IntuneFeaturesTests.OSX'
  target 'CompileFeatures'

  pod 'HDF5Kit', '~> 0.2', inhibit_warnings: true
  pod 'Peak/AudioFile', git: 'https://github.com/hoseking/Peak.git', branch: 'master'
  pod 'Peak/MIDI', git: 'https://github.com/hoseking/Peak.git', branch: 'master'
  pod 'Upsurge', '~> 0.8'
end

abstract_target 'ios' do
  platform :ios, '9.3'
  target 'IntuneFeatures.iOS'
  target 'IntuneFeaturesTests.iOS'

  pod 'HDF5Kit', '~> 0.2', inhibit_warnings: true
  pod 'Peak/MIDI', git: 'https://github.com/hoseking/Peak.git', branch: 'master'
  pod 'Upsurge', '~> 0.8'
end
