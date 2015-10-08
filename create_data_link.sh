#!/bin/sh
#
# This script will create a symbolic link to the audio data in the current
# directory and copy the audio data to the Shared Playground Data folder.
# The audio data should be in the "~/Box Sync" folder.
#

if [ ! -L "AudioData" ]; then
  ln -s "$HOME/Box Sync/Intune Music/Training" AudioData
fi

rm -rf "$HOME/Documents/Shared Playground Data/AudioData"
mkdir -p "$HOME/Documents/Shared Playground Data/AudioData"
cp -R "$HOME/Box Sync/Intune Music/Training/" "$HOME/Documents/Shared Playground Data/AudioData"
