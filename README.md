# Intune Features

The **IntuneFeatures** framework contains code to generate features from audio files and feature labels from the respective MIDI files. Currently supports these features:

- [x] Log-scale specturm power estimate by bands
- [x] Spectrum power flux
- [x] Peak power
- [x] Peak power flux
- [x] Peak locations

The **CompileFeatures** command line app takes audio and MIDI files as input and generates HDF5 databases with the features and the labels. These HDF5 files can then be used to train a neural network for transcription or related tasks.

## Features

Features are extracted from each consecutive window of audio data. The window size and the step size between windows can be configured, but the window size must be a power of 2. Each window is then multiplied by the [Hamming windowing function](https://en.wikipedia.org/wiki/Window_function#Hamming_window). To get the spectal power the FFT is computed for each window and the resulting spectrum is divided into bands of the [equal temperament](https://en.wikipedia.org/wiki/Equal_temperament) scale.

Peaks are extracted from the FFT and filtered by a height threshold and by a minimum peak distance requirement. Peak locations are computed for each band as the distance between the peak's frequency and the band's middle frequency.

---

## License

**IntuneFeatures** is available under the MIT license. See the LICENSE file for more info. Copyright © 2016 Venture Media Labs.
