#!/usr/bin/env ruby

require 'nokogiri'

def step_has_sharp(step)
  sharps = ["C", "D", "F", "G", "A"]
  return sharps.include?(step)
end

ARGV.each do |file|
  fp = File.open(file)
  doc = Nokogiri::XML(fp)
  fp.close

  doc_step    = doc.at_xpath("/score-partwise/part/measure/note/pitch/step")
  doc_octave  = doc.at_xpath("/score-partwise/part/measure/note/pitch/octave")
  doc_alter   = doc.at_xpath("/score-partwise/part/measure/note/pitch/alter")

  steps = ["C", "D", "E", "F", "G", "A", "B"]
  for octave in 1..7
    for step in steps
      doc_octave.content = octave
      doc_step.content = step
      doc_alter.content = "0"
      File.open("out/#{step}#{octave}.xml", "w") { |f| f.print(doc.to_xml) }

      if step_has_sharp(step)
        doc_alter.content = "1"
        File.open("out/#{step}#{octave}#.xml", "w") { |f| f.print(doc.to_xml) }
      end
    end
  end

end
