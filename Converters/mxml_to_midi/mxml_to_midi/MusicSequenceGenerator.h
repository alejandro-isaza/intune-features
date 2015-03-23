//  Copyright (c) 2015 Venture Media Labs. All rights reserved.

#pragma once
#include <mxml/dom/Score.h>
#include <mxml/EventFactory.h>
#include <mxml/EventSequence.h>
#include <mxml/ScoreProperties.h>

#include <AudioToolbox/MusicPlayer.h>
#include <vector>

class MusicSequenceGenerator {
public:
    struct MusicSequenceDeleter {
        void operator()(MusicSequence musicSequence) {
            OSStatus status = noErr;
            
            UInt32 trackCount;
            MusicSequenceGetTrackCount(musicSequence, &trackCount);

            MusicTrack track;
            for (int i = 0; i < trackCount; i++) {
                MusicSequenceGetIndTrack (musicSequence, i, &track);
                status = MusicSequenceDisposeTrack(musicSequence, track);
            }

            DisposeMusicSequence(musicSequence);

            if (status != noErr)
                throw std::runtime_error("MusicSequenceGenerator::MusicSequenceDeleter");
        }
    };

    using MidiNumber = unsigned int;
    using MusicSequenceUniquePointer = std::unique_ptr<OpaqueMusicSequence, MusicSequenceDeleter>;

public:
    static MusicSequenceUniquePointer generateFromScore(const mxml::dom::Score& score, const float tempoMultiplier);

private:
    struct NoteEvent {
        MIDINoteMessage message;
        MusicTimeStamp timeStamp;
    };
    struct TempoEvent {
        Float64 bpm;
        MusicTimeStamp timeStamp;
    };

private:
    MusicSequenceGenerator(const mxml::dom::Score& score, const float tempoMultiplier);
    void buildMidiEvents();
    void buildMusicSequence();
    NoteEvent buildNoteEventFromNote(const mxml::dom::Note& note, Float32 duration, MusicTimeStamp timeStamp);
    MIDINoteMessage buildMidiNoteFromNote(const mxml::dom::Note& note, Float32 duration);
    UInt8 velocityForNote(const mxml::dom::Note& note);

private:
    const mxml::dom::Score& _score;

    MusicSequenceUniquePointer _musicSequence;
    std::unique_ptr<mxml::ScoreProperties> _scoreProperties;
    std::unique_ptr<mxml::EventSequence> _eventSequence;
    std::vector<TempoEvent> _tempoEvents;
    std::vector<NoteEvent> _noteEvents;
    float _tempoMultiplier;
};
