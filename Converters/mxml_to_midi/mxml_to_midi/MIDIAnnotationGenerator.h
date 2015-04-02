//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#pragma once

#include <mxml/dom/Score.h>
#include <mxml/EventFactory.h>
#include <mxml/EventSequence.h>
#include <mxml/ScoreProperties.h>

#include <tempo/Annotation.h>

#include <AudioToolbox/MusicPlayer.h>
#include <string>

class MIDIAnnotationGenerator {
public:
    static void generate(const mxml::dom::Score& score, const float tempoMultiplier, const std::string& outputFile);

private:
    MIDIAnnotationGenerator(const mxml::dom::Score& score, const float tempoMultiplier, const std::string& outputFile);
    void buildAnnotationEvents();
    void writeAnnotationEvents();

private:
    const mxml::dom::Score& _score;
    std::unique_ptr<mxml::ScoreProperties> _scoreProperties;
    std::unique_ptr<mxml::EventSequence> _eventSequence;

    tempo::Annotations _annotations;
    float _tempoMultiplier;
    const std::string& _outputFile;
};
