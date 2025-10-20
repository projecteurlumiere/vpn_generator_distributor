class Admin::InstructionsController < Admin::BaseController
  def call
    state = current_user.state_array
    @state_controller, @substate, * = state
    _, _, @instruction_path, @step  = state

    @step = @step.to_i

    if @state_controller == self.class.name && (message.document || message.photo)
      handle_upload
    elsif @substate == "instruction_review"
      handle_review
    else
      raise ApplicationController::RoutingError
    end
  end

  def upload
    current_user.update(state: "#{self.class.name}|instruction_upload")
    reply("Пожалуйста, прикрепите YAML файл с инструкцией.")
  end

  def continue_review(filename)
    new_path = File.join("./tmp/instructions", filename)
    current_user.update(state: "#{self.class.name}|instruction_review|#{new_path}|0")
    instruction_step(new_path, 0)
  end

  def menu
    reply_with_inline_buttons("Следующие действия доступны для работы с инструкциями:", [
      admin_menu_inline_button,
      {
        "Посмотреть инструкции" => callback_name("list")
      },
      {
        "Инструкции-черновики" => callback_name("under_review")
      },
      {
        "Загрузить инструкцию" => callback_name("upload")
      }
    ])
  end

  def list
    msg = <<~TXT
      Загружены и работают следующие инструкции:
      #{Instructions.instance.titles.join("\n")}
    TXT

    buttons = Instructions.instance.paths.map do |path|
      filename = File.basename(path)
      { "Скачать #{filename}" => callback_name("download_yml", filename) }
    end

    buttons.unshift(admin_menu_inline_button)

    reply_with_inline_buttons(msg, buttons)
  end

  def under_review
    msg = <<~TXT
      /admin, чтобы вернуться
      *
      *
      Выберите инструкцию-черновик ниже, чтобы отредактировать её.
    TXT

    pending = Instructions.instance.pending.map do |path|
      title = YAML.load_file(path, symbolize_names: true)[:title]
      filename = File.basename(path)

      { 
        "Продолжить ревью #{title} (#{filename})" => callback_name(Admin::InstructionsController, "continue_review", filename)
      }
    end

    reply_with_inline_buttons(msg, [admin_menu_inline_button, *pending])
  end

  def download_yml(filename)
    path = File.join("./data/instructions", filename)
    unless File.exist?(path)
      reply("Файл не найден: #{filename}")
      return
    end

    bot.api.send_document(
      chat_id:,
      document: Faraday::UploadIO.new(path, 'application/x-yaml'),
      caption: "Инструкция: #{filename}"
    )
  end

  private

  def handle_upload
    case @substate
    in "instruction_upload" if message.document.nil? || !message.document.file_name.match?(/\.(ya?ml)\z/i)
      reply("Пожалуйста, загрузите файл с расширением .yml или .yaml")
    in "instruction_upload"        
      download_instruction
    in "instruction_review" if message.document
      reply("Изображения, отправленные в качестве файлов (документов) не подходят.\nОтправляйте их как обычные картинки.")
    in "instruction_review"
      memorize_image
    else
      raise ApplicationController::RoutingError
    end
  end

  def handle_review
    $mutex.sync do
      current_instruction = YAML.load_file(@instruction_path, symbolize_names: true)
      actions = current_instruction[:steps].map { |step| step[:actions] }.flatten

      case message.text
      in "/admin clear_images" | "Удалить изображения"
        current_instruction[:steps][@step].delete(:images)
        File.write(@instruction_path, current_instruction.to_yaml)
        instruction_step
      in "/admin reject_instruction" | "Отклонить инструкцию"
        FileUtils.rm(@instruction_path)
        current_user.update(state: nil)
        reply("Инструкция снята с ревью.\n/start - чтобы вернуться к боту\n/admin - чтобы посмотреть доступные команды для администрации")
      in "Заново"
        state = "#{self.class.name}|instruction_review|#{@instruction_path}|0"
        current_user.update(state:)
        instruction_step(new_path, 0)
      in "Принять инструкцию"
        filename = @instruction_path.split("/").last
        FileUtils.mv(@instruction_path, "./data/instructions/#{filename}")
        Instructions.instance.load!
        Routes.instance.build!
        reply("Инструкция загружена и доступна для использования")
        current_user.update(state: nil)
      in String if actions.any?(message.text)
        @step += 1

        instruction_step
        state = [@state_controller, @substate, @instruction_path, @step].join("|")
        current_user.update(state:)
      in "Это последний шаг инструкции"
        reply_with_buttons("Инструкция #{current_instruction[:title]} - принять или отклонить?\nОтклонённая инструкция будет удалена; Принятая инструкция будет выложена в общий доступ.",
          [
            ["Принять инструкцию", "Заново", "Отклонить инструкцию"]
          ]
        )
      else
        reply("Нажмите любую кнопку для продолжения или загрузите изображения для этого шага инструкции", reply_markup: nil)
      end
    end
  end

  def download_instruction
    dest_path = File.join("./tmp/instructions", message.document.file_name)
    path = download_attachment(message.document.file_id, dest_path)

    if Instructions.instance.errors_for(path) in [:invalid, { errors: errors }]
      msg = <<~TXT
        Файл-инструкций недействителен. Обнаружены следующие ошибки:

        #{errors.join("\n")}
      TXT

      FileUtils.rm_f(path)

      reply(msg)
      return
    end

    $mutex.sync do
      instruction = YAML.load_file(path, symbolize_names: true)
      new_title = instruction[:title].downcase
      new_path = File.join(File.dirname(path), "#{new_title}.yml")
      FileUtils.mv(path, new_path) unless File.expand_path(path) == File.expand_path(new_path)
      
      state = "#{self.class.name}|instruction_review|#{new_path}|0"
      current_user.update(state:)
      
      instruction_step(new_path, 0)
    end
  end

  def instruction_step(path = @instruction_path, step = @step)
    current_instruction = YAML.load_file(path, symbolize_names: true)
    current_step = current_instruction[:steps][step]
    photos = current_step[:images]

    current_step[:actions] = ["Это последний шаг инструкции"] if step >= current_instruction[:steps].size - 1
    current_step[:actions] << "Удалить изображения" if photos&.any?

    reply_with_buttons(
      current_step[:text],
      current_step[:actions].map { |a| [a] },
      photos:,
      parse_mode: "Markdown"
    )

    if key_name = current_step[:issue_key]
      reply("Выдаём ключ #{key_name}", reply_markup: nil)
    end 
  end

  def memorize_image
    image_id = message.photo.last.file_id

    $mutex.sync do
      current_instruction = YAML.load_file(@instruction_path, symbolize_names: true)
      current_instruction[:steps][@step][:images] ||= []
      current_instruction[:steps][@step][:images] << image_id

      File.write(@instruction_path, current_instruction.to_yaml)
    end

    instruction_step
  end
end
