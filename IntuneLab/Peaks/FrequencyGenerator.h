//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#pragma once

#include <tempo/Buffer.h>
#include <tempo/Utilities.h>

template <typename T>
class FrequencyGenerator {
public:
    static void generate(const int midiNote, tempo::Buffer<T>& buffer, const double sampleRate);
};

template<typename T>
inline void FrequencyGenerator<T>::generate(const int midiNote, tempo::Buffer<T>& buffer, const double sampleRate) {
    const auto midiNoteFrequency = tempo::frequencyForNote(midiNote);
    const auto baseFrquency = sampleRate / (buffer.capacity() * 2);

    auto multiplier = 1.0;
    auto power = 1.0;

    auto sliceIndex = std::round(midiNoteFrequency / baseFrquency);
    while (sliceIndex < buffer.capacity()) {
        buffer[sliceIndex] = power;
        power *= 0.9;
        multiplier += 1.0;
        sliceIndex = std::round(midiNoteFrequency * multiplier / baseFrquency);
    }
}
