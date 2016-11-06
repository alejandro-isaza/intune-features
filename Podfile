use_frameworks!

abstract_target 'osx' do
  platform :osx, '10.12’
  target 'IntuneFeaturesTests.OSX'
  target 'IntuneFeatures.OSX'
  target 'CompileFeatures'

  pod 'HDF5Kit', '~> 0.2', inhibit_warnings: true
  pod 'Peak/AudioFile', git: 'https://github.com/hoseking/Peak.git', branch: 'master'
  pod 'Peak/MIDI', git: 'https://github.com/hoseking/Peak.git', branch: 'master'
  pod 'Upsurge', '~> 0.8'
end

target 'IntuneFeatures.iOS' do
  platform :ios, '9.3'
  target 'IntuneFeaturesTests.iOS'

  pod 'HDF5Kit', '~> 0.2', inhibit_warnings: true
  pod 'Peak/MIDI', git: 'https://github.com/hoseking/Peak.git', branch: 'master'
  pod 'Upsurge', '~> 0.8'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = ‘3.0.1’
    end
  end
end
