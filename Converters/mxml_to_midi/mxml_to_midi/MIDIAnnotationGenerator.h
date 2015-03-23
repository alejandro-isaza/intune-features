//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#pragma once

#include <json11/json11.hpp>

#include <mxml/dom/Score.h>
#include <mxml/EventFactory.h>
#include <mxml/EventSequence.h>
#include <mxml/ScoreProperties.h>

#include <AudioToolbox/MusicPlayer.h>
#include <string>
#include <vector>

class MIDIAnnotationGenerator {
public:
    static void generate(const mxml::dom::Score& score, const float tempoMultiplier, const std::string& outputFile);

private:
    MIDIAnnotationGenerator(const mxml::dom::Score& score, const float tempoMultiplier, const std::string& outputFile);
    void buildAnnotationEvents();
    void writeAnnotationEvents();

private:
    struct AnnotationEvent {
        int timeStamp; // event time in milliseconds
        float measureNumber; // fractional event measure number
        json11::Json to_json() const {
            return json11::Json::object {
                {"timeStamp", timeStamp},
                {"measureNumber", measureNumber}
            };
        }
    };

private:
    const mxml::dom::Score& _score;
    std::unique_ptr<mxml::ScoreProperties> _scoreProperties;
    std::unique_ptr<mxml::EventSequence> _eventSequence;

    std::vector<AnnotationEvent> _annotationEvents;
    float _tempoMultiplier;
    const std::string& _outputFile;
};
