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

  def errors_for(path)
    errors = []

    begin
      slide = YAML.load_file(path, symbolize_names: true)
    rescue StandardError
      return [:invalid, { errors: ["Не получилось обработать файл.\nПроверьте синтаксис: все ли отступы и служебные символы на месте?"] }]
    end

    if !slide[:text].is_a?(String) || slide[:text].empty?
      errors << "(text) Отсутствует текст сообщения"
    elsif slide[:text].size > 4096
      errors << "(text) Размер сообщения не может превышать 4096 символов"
    end

    if !slide[:actions].is_a?(Array) || slide[:actions].none?
      errors << "(actions) Отсутствуют кнопки для следующих действий"
    end

    result = errors.any? ? :invalid : :valid

    [result, { errors: }]
  rescue StandardError
    errors.unshift("Произошла непредвиденная ошибка! Вы точно всё заполнили верно?")
    [:invalid, { errors: }]
  end
end