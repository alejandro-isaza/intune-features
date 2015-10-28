#!/bin/sh
#
# This script will create a symbolic link to the audio data in the current
# directory and copy the audio data to the Shared Playground Data folder.
# The audio data should be in the "/Volumes/Archive/IntuneTrainingData" folder.
#

if [[ ! -d "/Volumes/Archive/IntuneTrainingData" ]]; then
  echo "Please mount APOLLO"
  exit 1
fi

if [[ ! -L "AudioData" ]]; then
  ln -s "/Volumes/Archive/IntuneTrainingData" AudioData
fi

read -p "Copy all the contentes into Shared Playground Data? " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

rm -rf "$HOME/Documents/Shared Playground Data/AudioData"
mkdir -p "$HOME/Documents/Shared Playground Data/AudioData"
cp -Rv "/Volumes/Archive/IntuneTrainingData/" "$HOME/Documents/Shared Playground Data/AudioData"
