# frozen_string_literal: true

require "fileutils"

# slides
slides_path = "data/slides"
FileUtils.mkdir_p(slides_path)

Dir.glob("seeds/data/slides/*").each do |file|
  target_path = File.join(slides_path, File.basename(file))
  next if File.exist?(target_path)

  FileUtils.cp(file, target_path)
end

# instructions
instructions_path = "data/instructions"
FileUtils.mkdir_p(instructions_path)

if Dir.glob("#{instructions_path}/*").none?
  Dir.glob("seeds/data/instructions/*").each do |file|
    target_path = File.join(instructions_path, File.basename(file))
    next if File.exist?(target_path)

    FileUtils.cp(file, target_path)
  end
end
