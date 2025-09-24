class Slides
  include Singleton

  def initialize
    load!
  end

  def load!
    @data = {}

    Dir.glob("data/slides/*.yml").each do |file|
      key = File.basename(file, ".yml")
      @data[key.to_sym] = YAML.load_file(file, symbolize_names: true)
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

  def paths
    Dir.glob("./data/slides/*.yml")
  end
end