#!/usr/bin/env ruby
#
# This script generates training and testing examples of audio files for use
# with audio_data_layer.
#
require 'optparse'

NOTES_DIR = "AudioData/Notes/"
FOLDERS = [
  "AcousticGrandPiano_YDP",
  "Arachno",
  "FFNotes",
  "MFNotes",
  "PPNotes",
  "FluidR3_GM2-2",
  "GeneralUser_GS_MuseScore_v1.442",
  "Piano_Rhodes_73",
  "Piano_Yamaha_DX7",
  "TimGM6mb",
  "VenturePiano"
]


def parseCommanLine()
  options = {
    extension: ".caf",
    training: "training.txt",
    testing: "testing.txt",
    firstNote: 24,
    lastNote: 96,
    matchingNote: 60,
    trainingToTestingRatio: 10
  }
  parser = OptionParser.new do |opts|
    opts.banner = "Usage: single.rb <data directory> [options]"

    opts.on("-e", "--extension EXTENSION", "Audio file extension") do |ext|
      options[:extension] = ext || ".caf"
      options[:extension].sub!(/\A\.?(?=.)/, ".")  # Ensure extension begins with dot.
    end
    opts.on("--training FILE", "The output file name for training examples") do |file|
      options[:training] = file || "training.txt"
    end
    opts.on("--testing FILE", "The output file name for testing examples") do |file|
      options[:testing] = file || "testing.txt"
    end
    opts.on("--ratio N", Float, "The ratio of training to testing files") do |n|
      options[:trainingToTestingRatio] = n
    end
    opts.on("--note N", Float, "The midi note to label \"1\"") do |n|
      options[:matchingNote] = n
    end
  end
  parser.parse!

  if ARGV[0].nil?
    puts parser.help()
    exit 1
  end

  return options
end

# Build a list of all the note audio files by note number
def buildFilePairs(rootPath, options)
  firstNote = options[:firstNote]
  lastNote = options[:lastNote]

  notePairs = []
  FOLDERS.each do |folder|
    (firstNote...lastNote).each do |i|
      noteRef  = "#{NOTES_DIR}#{folder}/#{i.to_s}#{options[:extension]}"
      notePath = "#{rootPath}/#{noteRef}"
      if File.exist?(notePath)
        notePairs << [noteRef, i]
      else
        puts "File '#{notePath}' not found"
      end
    end
  end

  return notePairs
end

def divideFilePairs(notePairs, options)
  shuffledNotes = notePairs.shuffle

  ratio = options[:trainingToTestingRatio]
  testingNotes = []
  trainingNotes = []

  i = 0
  shuffledNotes.each do |notePair|
      if (i % ratio) == 0
        testingNotes << "#{notePair[0]} #{label(notePair[1])}"
      else
        trainingNotes << "#{notePair[0]} #{label(notePair[1])}"
      end
    i += 1
  end

  return testingNotes, trainingNotes
end

def label(note)
  note == 60 ? 1 : 0
end

def write(array, filePath)
  File.open(filePath, "w") do |f|
    array.each do |line|
      f.puts(line)
    end
  end
end

rootPath = ARGV[0]
options = parseCommanLine()

notePairs = buildFilePairs(rootPath, options)
test, train = divideFilePairs(notePairs, options)
write(test, "#{rootPath}/data/#{options[:testing]}")
write(train, "#{rootPath}/data/#{options[:training]}")
