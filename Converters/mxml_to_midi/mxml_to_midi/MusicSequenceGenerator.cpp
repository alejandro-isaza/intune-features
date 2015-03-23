//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#include "MusicSequenceGenerator.h"


MusicSequenceGenerator::MusicSequenceUniquePointer MusicSequenceGenerator::generateFromScore(const mxml::dom::Score& score, const float tempoMultiplier) {
    MusicSequenceGenerator generator(score, tempoMultiplier);
    generator.buildMidiEvents();
    generator.buildMusicSequence();
    return std::move(generator._musicSequence);
}

MusicSequenceGenerator::MusicSequenceGenerator(const mxml::dom::Score& score, const float tempoMultiplier)
: _score(score),
  _tempoMultiplier(tempoMultiplier)
{
    _scoreProperties.reset(new mxml::ScoreProperties(score));
    mxml::EventFactory eventFactory(score, *_scoreProperties);
    _eventSequence = eventFactory.build();
}

void MusicSequenceGenerator::buildMusicSequence() {
    OSStatus status = noErr;

    MusicSequence musicSequence;
    status = NewMusicSequence(&musicSequence);
    _musicSequence.reset(musicSequence);

    MusicTrack tempoTrack;
    status = MusicSequenceGetTempoTrack(_musicSequence.get(), &tempoTrack);
    for (auto& tempoEvent : _tempoEvents) {
        status = MusicTrackNewExtendedTempoEvent(tempoTrack, tempoEvent.timeStamp, tempoEvent.bpm);
    }

    MusicTrack track;
    status = MusicSequenceNewTrack(_musicSequence.get(), &track);
    for (auto& noteEvent : _noteEvents) {
        status = MusicTrackNewMIDINoteEvent(track, noteEvent.timeStamp, &noteEvent.message);
    }
    
    if (status != noErr)
        throw std::runtime_error("MusicSequenceGenerator::buildMusicSequence");
}

void MusicSequenceGenerator::buildMidiEvents() {
    auto previousTempo = 0.0f;
    for (auto& event : _eventSequence->events()) {
        const auto& currentTempo = _scoreProperties->tempo(event.measureIndex(), event.measureTime());
        const auto& currentBeat = static_cast<MusicTimeStamp>(event.absoluteTime()) / _scoreProperties->divisionsPerBeat(event.measureIndex());

        if (previousTempo != currentTempo) {
            previousTempo = currentTempo;

            TempoEvent tempoEvent = {
                .timeStamp = currentBeat,
                .bpm = currentTempo * _tempoMultiplier
            };
            _tempoEvents.push_back(tempoEvent);
        }

        for (auto& onNote : event.onNotes()) {
            if (onNote->rest)
                continue;

            auto noteEvent = buildNoteEventFromNote(*onNote, event.wallTimeDuration(), currentBeat);
            _noteEvents.push_back(noteEvent);
        }
    }
}

MusicSequenceGenerator::NoteEvent MusicSequenceGenerator::buildNoteEventFromNote(const mxml::dom::Note& note, Float32 duration, MusicTimeStamp timeStamp) {
    NoteEvent noteEvent = {
        noteEvent.message = buildMidiNoteFromNote(note, duration),
        noteEvent.timeStamp = timeStamp
    };

    return noteEvent;
}

MIDINoteMessage MusicSequenceGenerator::buildMidiNoteFromNote(const mxml::dom::Note& note, Float32 duration) {
    MIDINoteMessage midiNote = {
        .note = static_cast<UInt8>(note.midiNumber()),
        .velocity = velocityForNote(note),
        .duration = duration
    };

    return midiNote;
}

UInt8 MusicSequenceGenerator::velocityForNote(const mxml::dom::Note& note) {
    // Get dynamic percentage value
    float dynamicPercentage = _scoreProperties->dynamics(note);

    // Convert dynamics percentage to MIDI velocity, from Intune - VMMIDIPlayer.mm
    float velocity = roundf(37 + dynamicPercentage * 0.9);
    if (velocity < 0) velocity = 0;
    if (velocity > 127) velocity = 127;

    return static_cast<UInt8>(velocity);
}
