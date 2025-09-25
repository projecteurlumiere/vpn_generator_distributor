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

  def paths
    Dir.glob("./data/instructions/*.yml")
  end

  def instruction_name_by_title(title)
    @data.find { |key, instruction| instruction[:title] == title }&.first
  end

  def pending
    Dir.glob("./tmp/instructions/*.yml")
  end

  def errors_for(path)
    errors = []

    begin
      slide = YAML.load_file(path, symbolize_names: true)
    rescue StandardError
      return [:invalid, { errors: ["Не получилось обработать файл.\nПроверьте синтаксис: все ли отступы и служебные символы на месте?"] }]
    end

    if slide[:title].nil?
      errors << "Отсутствует название (title) инструкции"
    elsif slide[:title].to_s.size > 13
      errors << "Название инструкции не может превышать 13 символов"
    end

    if slide[:steps].to_a.none?
      errors << "Отсутсвуют шаги инструкции"
    else
      if slide[:steps].any? { |step| step[:actions].to_a.none? }
        errors << "На одном из шагов отсутствуют кнопки-действия (actions)"
      end

      if slide[:steps].all? { |step| step[:issue_key].to_s.empty? }
        errors << "Вы забыли выдать ключ на одном из шагово инструкции!"
      end

      if (slide[:steps].count { |step| step[:issue_key] }) > 1
        errors << "Вы выдаёте ключ более, чем один раз"
      end

      valid_configs = %w[amnezia wireguard outline vless].freeze
      if slide[:steps].any? { |step| valid_configs.none?(step[:issue_key]) }
          errors << "Поле issue_key может иметь только одно из следующих значений: #{valid_configs.join(" ")}"
      end

      if slide[:steps].any? { step[:text].to_s.empty? }
        errors << "Отсутствует текст сообщения на одном из шагов"
      end

      if slide[:steps].any? { step[:text].to_s.size > 4096 }
        errors << "Текст сообщения одного из шагов превышает 4096 символов"
      end
    end


    result = errors.any? ? :invalid : :valid

    [result, { errors: }]
  rescue StandardError
    errors.unshift("Произошла непредвиденная ошибка! Вы точно всё заполнили верно?")
    [:invalid, { errors: }]
  end
end
