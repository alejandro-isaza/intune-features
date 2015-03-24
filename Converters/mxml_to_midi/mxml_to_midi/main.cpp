//  Copyright (c) 2015 Venture Media. All rights reserved.

#include "MusicSequenceGenerator.h"
#include "MIDIAnnotationGenerator.h"

#include <lxml/lxml.h>
#include <mxml/EventFactory.h>
#include <mxml/ScoreProperties.h>
#include <mxml/dom/Note.h>
#include <mxml/parsing/ScoreHandler.h>

#include <CoreFoundation/CoreFoundation.h>
#include <AudioToolbox/MusicPlayer.h>
#include <fstream>
#include <iostream>

void printUsage(int argc, const char * argv[]);
void createMidiFiles(std::string inputFile, float tempoMultiplier);
std::unique_ptr<mxml::dom::Score> loadScore(std::string file);
std::unique_ptr<mxml::dom::Score> loadScoreFromXML(std::string file);
std::unique_ptr<mxml::dom::Score> loadScoreFromMXL(std::string file);
bool stringHasSuffix(std::string string, std::string suffix);

int main(int argc, const char * argv[]) {
    std::string inputFile;
    float tempoMultiplier = 1.0f;

    for (int i = 1; i < argc; i += 1) {
        if (inputFile.empty())
            inputFile = argv[i];
        else
            tempoMultiplier = std::stof(argv[i]);
    }

    if (inputFile.empty()) {
        printUsage(argc, argv);
        return 1;
    }

    createMidiFiles(inputFile, tempoMultiplier);

    return 0;
}

void printUsage(int argc, const char * argv[]) {
    std::cerr << "Usage: \n";
    std::cerr << "    " << argv[0] << " <input> [<tempoMultiplier>]\n\n";
    std::cerr << "    input            Input MusicXML file path. A music xml file.\n";
    std::cerr << "    tempoMultiplier  Optional tempo multiplier to to the midi tempo events.\n";
}

void createMidiFiles(std::string inputFile, float tempoMultiplier) {
    auto score = loadScore(inputFile + ".xml");
    MusicSequenceGenerator::generate(*score, tempoMultiplier, inputFile + ".mid");
    MIDIAnnotationGenerator::generate(*score, tempoMultiplier, inputFile + ".json");
}

std::unique_ptr<mxml::dom::Score> loadScore(std::string file) {
    if (stringHasSuffix(file, ".xml")) {
        return loadScoreFromXML(file);
    } else if (stringHasSuffix(file, ".mxl")) {
        return loadScoreFromXML(file);
    }

    throw std::runtime_error("loadScore");
}

std::unique_ptr<mxml::dom::Score> loadScoreFromXML(std::string file) {
    mxml::parsing::ScoreHandler handler;
    std::ifstream is(file);
    lxml::parse(is, file, handler);

    return handler.result();
}

std::unique_ptr<mxml::dom::Score> loadScoreFromMXL(std::string file) {
    // TODO
    throw std::runtime_error("loadScoreFromMXL");
}

bool stringHasSuffix(std::string string, std::string suffix) {
    if (string.length() >= suffix.length())
        return string.compare(string.length() - suffix.length(), suffix.length(), suffix) == 0;
    return false;
}
