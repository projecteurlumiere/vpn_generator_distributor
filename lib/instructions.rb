require "yaml"
require "singleton"

class Instructions
  include Singleton

  def initialize
    load!
  end

  def load!
    @data = {}

    Dir.glob("data/instructions/*.yml").each do |file|
      key = File.basename(file, ".yml")
      @data[key] = YAML.load_file(file, symbolize_names: true)
    end
  end

  def [](key)
    @data[key]
  end

  def all
    @data
  end

  def titles
    @data.map { |_file_name, instruction| instruction[:title] }
  end

  def instruction_name_by_title(title)
    @data.find { |key, instruction| instruction[:title] == title }&.first
  end

  def pending
    Dir.glob("./tmp/instructions/*.yml")
  end
end
