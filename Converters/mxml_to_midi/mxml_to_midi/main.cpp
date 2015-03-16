//  Copyright (c) 2015 Venture Media. All rights reserved.

#include "MusicSequenceGenerator.h"

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
bool createMidiFile(std::string inputFile, std::string outputFile);
std::unique_ptr<mxml::dom::Score> loadScore(std::string file);
std::unique_ptr<mxml::dom::Score> loadScoreFromXML(std::string file);
std::unique_ptr<mxml::dom::Score> loadScoreFromMXL(std::string file);
bool stringHasSuffix(std::string string, std::string suffix);

int main(int argc, const char * argv[]) {
    std::string inputFile;
    std::string outputFile;

    for (int i = 1; i < argc; i += 1) {
        if (inputFile.empty())
            inputFile = argv[i];
        else if (outputFile.empty())
            outputFile = argv[i];
    }

    if (inputFile.empty() || outputFile.empty()) {
        printUsage(argc, argv);
        return 1;
    }

    int result = (int)createMidiFile(inputFile, outputFile);

    return result;
}

void printUsage(int argc, const char * argv[]) {
    std::cerr << "Usage: \n";
    std::cerr << "    " << argv[0] << " <input> [<output>]\n\n";
    std::cerr << "    input   Input MusicXML file path. A compressed .mxl file.\n";
    std::cerr << "    output  Optional output file path.\n";
}

bool createMidiFile(std::string inputFile, std::string outputFile) {
    auto score = loadScore(inputFile);
    auto musicSequence = MusicSequenceGenerator::generateFromScore(*score);

    std::string outputFileURL = outputFile;
    CFStringRef outputFileURLRef = CFStringCreateWithCString(NULL, outputFileURL.c_str(), kCFStringEncodingISOLatin1);
    CFURLRef fileURL = CFURLCreateWithFileSystemPath(NULL, outputFileURLRef, kCFURLPOSIXPathStyle, false);
    OSStatus status = MusicSequenceFileCreate(musicSequence.get(), fileURL, kMusicSequenceFile_MIDIType, kMusicSequenceFileFlags_EraseFile, 0);

    return status == noErr;
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
