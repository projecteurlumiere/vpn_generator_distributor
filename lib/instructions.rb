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

    if !slide[:title].is_a?(String) || slide[:title].empty?
      errors << "(title) Отсутствует название инструкции"
    elsif slide[:title].size > 13
      errors << "(title) Название инструкции не может превышать 13 символов"
    end

    if !slide[:steps].is_a?(Array) || slide[:steps].none?
      errors << "(steps) Отсутствуют шаги инструкции"
    else
      if slide[:steps].any? { |step| !step[:actions].is_a?(Array) || step[:actions].none? }
        errors << "(steps|actions) На одном из шагов отсутствуют кнопки-действия"
      end

      if slide[:steps].all? { |step| !step[:issue_key].is_a?(String) || step[:issue_key].empty? }
        errors << "(steps|issue_key) Вы забыли выдать ключ для подключения к VPN"
      end

      if (slide[:steps].count { |step| step[:issue_key] }) > 1
        errors << "(steps|issue_key) Вы выдаёте ключ более, чем один раз"
      end

      if slide[:steps].any? { |step| step[:issue_key].is_a?(String) && Key::VALID_CONFIGS.none?(step[:issue_key]) }
        errors << "(steps|issue_key) Поле issue_key может иметь только одно из следующих значений: #{Key::VALID_CONFIGS.join(" ")}"
      end

      if slide[:steps].any? { |step| !step[:text].is_a?(String) || step[:text].empty? }
        errors << "(steps|text) Отсутствует текст сообщения на одном из шагов"
      elsif slide[:steps].any? { |step| step[:text].size > 4096 }
        errors << "Текст сообщения одного из шагов превышает 4096 символов"
      end
    end


    result = errors.any? ? :invalid : :valid

    [result, { errors: }]
  rescue StandardError => e
    LOGGER.error "Error when validating instruction yaml: #{e}\n#{e.full_message}"
    errors.unshift("Произошла непредвиденная ошибка! Вы точно всё заполнили верно?")
    [:invalid, { errors: }]
  end
end
