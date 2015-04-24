#!/usr/bin/env ruby

require 'nokogiri'

def midi_value(octave, note)
  return 12 + (octave * 12) + note
end

ARGV.each do |file|
  fp = File.open(file)
  doc = Nokogiri::XML(fp)
  fp.close

  doc_step    = doc.at_xpath("/score-partwise/part/measure/note/pitch/step")
  doc_octave  = doc.at_xpath("/score-partwise/part/measure/note/pitch/octave")
  doc_alter   = doc.at_xpath("/score-partwise/part/measure/note/pitch/alter")

  notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
  for octave in 1..7
    notes.each_with_index do |note, note_index|
      doc_octave.content = octave
      doc_step.content = note[0]
      doc_alter.content = note.length == 1 ? "0" : "1"
      midi_value = midi_value(octave, note_index)
      note_str = note.dup.insert(1, octave.to_s)
      File.open("out/#{midi_value} - #{note_str}.xml", "w") { |f| f.print(doc.to_xml) }
    end
  end
end
