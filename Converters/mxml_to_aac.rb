#!/usr/bin/env ruby

TEMPO_MULTIPLIER = 1.0

def process(file)
  mxml_to_midi(file)
  midi_to_wav(file)
  wav_to_aac(file)
end

def mxml_to_midi(file)
  `bin/mxml_to_midi "#{file}" #{TEMPO_MULTIPLIER}`
end

def midi_to_wav(file)
  #`fluidsynth "bin/grand_piano.sf2" "#{file}.mid" -F "#{file}.wav" -O float -g 4`
  `timidity "#{file}.mid" --config-string="soundfont bin/grand_piano.sf2" -Ow -o "#{file}.wav"`
end

def wav_to_aac(file)
  `afconvert -d aac -f caff "#{file}.wav" "#{file}.caf"`
end

ARGV.each do |file|
  process(file)
end
