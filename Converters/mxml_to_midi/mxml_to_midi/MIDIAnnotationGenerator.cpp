//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#include "MIDIAnnotationGenerator.h"

#include <tempo/AnnotationsSerialization.h>
#include <fstream>
#include "Utilities.h"

using namespace tempo;


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
    using TimeType = Annotation::DurationType::rep;
    std::map<Annotation::NoteType, TimeType> noteOnTimes;

    for (auto& event : _eventSequence->events()) {
        auto timeStamp = static_cast<TimeType>(event.wallTime() * 1000 * _tempoMultiplier);

        Annotation annotation;
        annotation.setTimeStamp(Annotation::DurationType(timeStamp));
        annotation.setMeasureIndex(static_cast<int>(event.measureIndex()));
        annotation.setDivision(event.measureTime());
        annotation.setDivisionCount(static_cast<float>(_scoreProperties->divisionsPerMeasure(event.measureIndex())));

        for (auto& offNote : event.offNotes()) {
            if (!util::isValidNote(*offNote))
                continue;

            auto midiNumber = offNote->midiNumber();
            if (midiNumber != 0)
                noteOnTimes.erase(midiNumber);
        }
        for (auto& onNote : event.onNotes()) {
            if (!util::isValidNote(*onNote))
                continue;

            auto midiNumber = onNote->midiNumber();
            if (midiNumber != 0)
                noteOnTimes[midiNumber] = timeStamp;
        }

        for (auto& pair : noteOnTimes)
            annotation.addOnNote(pair.first, Annotation::DurationType(timeStamp - pair.second));

        _annotations.addAnnotation(annotation);
    }
}

void MIDIAnnotationGenerator::writeAnnotationEvents() {
    std::ofstream os(_outputFile);
    auto json = AnnotationsSerialization::serializeAnnotations(_annotations);
    os << json;
    os.close();
}
