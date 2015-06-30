#!/usr/bin/env ruby

require 'fileutils'

TEMPO_MULTIPLIER = 1.0

def process(file)
  dir = File.dirname(file)
  name = File.basename(file, ".xml")

  mxml_to_midi(dir, name)
  midi_to_wav(dir, name)
end

def mxml_to_midi(dir, name)
  file = dir + File::SEPARATOR + name
  `bin/mxml_to_midi "#{file}" #{TEMPO_MULTIPLIER}`
end

def midi_to_wav(dir, name)
  input = dir + File::SEPARATOR + name + ".mid"
  sound_fonts = [
    "sf/AcousticGrandPiano_YDP.sf2",
    "sf/Arachno.sf2",
    "sf/FluidR3_GM2-2.sf2",
    "sf/GeneralUser_GS_MuseScore_v1.442.sf2",
    "sf/Piano_Rhodes_73.sf2",
    "sf/Piano_Yamaha_DX7.sf2",
    "sf/TimGM6mb.sf2"
  ]

  sound_fonts.each do |soundfont|
    sfname = File.basename(soundfont, ".*")
    sfdir = dir + File::SEPARATOR + sfname
    wave = sfdir + File::SEPARATOR + name + ".wav"
    FileUtils::mkdir_p(sfdir)

    `fluidsynth "#{soundfont}" "#{input}" -F "#{wave}" -O float -g 4`
    #{}`timidity "#{input}" --config-string="soundfont #{soundfont}" -Ow -o "#{wave}"`
    wav_to_aac(wave)
    File.delete(wave)
  end
end

def wav_to_aac(input)
  output = File.dirname(input) + File::SEPARATOR + File.basename(input, ".wav") + ".caf"
  `afconvert -d aac -f caff "#{input}" "#{output}"`
end

ARGV.each do |file|
  process(file)
end
