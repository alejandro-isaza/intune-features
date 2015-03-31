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
    std::map<int, int> noteOnTimes;

    for (auto& event : _eventSequence->events()) {
        auto divisionsPerMeasure = static_cast<float>(_scoreProperties->divisionsPerMeasure(event.measureIndex()));
        auto measureNumber = event.absoluteTime() / divisionsPerMeasure;
        auto timeStamp = static_cast<int>(event.wallTime() * 1000 * _tempoMultiplier);

        for (auto& onNote : event.offNotes()) {
            auto midiNumber = onNote->midiNumber();
            if (midiNumber != 0)
                noteOnTimes.erase(midiNumber);
        }
        for (auto& onNote : event.onNotes()) {
            auto midiNumber = onNote->midiNumber();
            if (midiNumber != 0)
                noteOnTimes[midiNumber] = timeStamp;
        }

        if (noteOnTimes.size() > 0) {
            AnnotationEvent annotationEvent = {
                .timeStamp = timeStamp,
                .measureNumber = measureNumber
            };
            for (auto& pair : noteOnTimes) {
                NoteState state = {
                    .midiNumber = pair.first,
                    .onDuration = timeStamp - pair.second
                };
                annotationEvent.notes.push_back(state);
            }
            _annotationEvents.push_back(annotationEvent);
        }
    }
}

void MIDIAnnotationGenerator::writeAnnotationEvents() {
    std::ofstream os(_outputFile);
    os << json11::Json(_annotationEvents).dump();
    os.close();
}
