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
    {
      file: "sf/AcousticGrandPiano_YDP.sf2",
      gain: 4
    },
    {
      file: "sf/Arachno.sf2",
      gain: 4
    },
    {
      file: "sf/FluidR3_GM2-2.sf2",
      gain: 4
    },
    {
      file: "sf/GeneralUser_GS_MuseScore_v1.442.sf2",
      gain: 4
    },
    {
      file: "sf/Piano_Rhodes_73.sf2",
      gain: 10
    },
    {
      file: "sf/Piano_Yamaha_DX7.sf2",
      gain: 1
    },
    {
      file: "sf/TimGM6mb.sf2",
      gain: 4
    }
  ]

  sound_fonts.each do |soundfont|
    sfname = File.basename(soundfont[:file], ".*")
    sfdir = dir + File::SEPARATOR + sfname
    wave = sfdir + File::SEPARATOR + name + ".wav"
    FileUtils::mkdir_p(sfdir)

    `fluidsynth "#{soundfont[:file]}" "#{input}" -F "#{wave}" -O float -g #{soundfont[:gain]}`
    #{}`timidity "#{input}" --config-string="soundfont #{soundfont[:file]}" -Ow -o "#{wave}"`
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
