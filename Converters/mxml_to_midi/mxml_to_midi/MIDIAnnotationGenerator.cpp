//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#include "MIDIAnnotationGenerator.h"

#include <fstream>

void MIDIAnnotationGenerator::generate(const mxml::dom::Score& score, const float tempoMultiplier, const std::string& outputFile) {
    MIDIAnnotationGenerator generator(score, tempoMultiplier, outputFile);
    generator.buildAnnotationEvents();
    generator.writeAnnotationEvents();
}

MIDIAnnotationGenerator::MIDIAnnotationGenerator(const mxml::dom::Score& score, const float tempoMultiplier, const std::string& outputFile)
: _score(score),
  _tempoMultiplier(tempoMultiplier),
  _outputFile(outputFile)
{
    _scoreProperties.reset(new mxml::ScoreProperties(score));
    mxml::EventFactory eventFactory(score, *_scoreProperties);
    _eventSequence = eventFactory.build();
}

void MIDIAnnotationGenerator::buildAnnotationEvents() {
    for (auto& event : _eventSequence->events()) {
        auto divisionsPerMeasure = static_cast<float>(_scoreProperties->divisionsPerMeasure(event.measureIndex()));
        auto measureNumber = event.absoluteTime() / divisionsPerMeasure;
        auto timeStamp = static_cast<int>(event.wallTime() * 1000 * _tempoMultiplier);

        MidiNoteVector midiNotes;
        for (auto& onNote : event.onNotes()) {
            if (onNote->rest)
                continue;
            midiNotes.push_back(onNote->midiNumber());
        }

        if (midiNotes.size() > 0) {
            AnnotationEvent annotationEvent = {
                .timeStamp = timeStamp,
                .measureNumber = measureNumber,
                .midiNotes = midiNotes
            };
            _annotationEvents.push_back(annotationEvent);
        }
    }
}

void MIDIAnnotationGenerator::writeAnnotationEvents() {
    std::ofstream os(_outputFile);
    os << json11::Json(_annotationEvents).dump();
    os.close();
}
