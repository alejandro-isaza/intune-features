#!/usr/bin/env ruby

def process(file)
  mxml_to_midi(file)
  midi_to_wav(file)
  wav_to_caf(file)
end

def mxml_to_midi(file)
  `bin/mxml_to_midi "#{file}" "#{file}.mid"`
end

def midi_to_wav(file)
  `fluidsynth "bin/grand_piano.sf2" "#{file}.mid" -F "#{file}.wav" -O float -g 5`
end

def wav_to_caf(file)
  `afconvert -d aac -f caff "#{file}.wav" "#{file}.caf"`
end

ARGV.each do |file|
  process(file)
end
