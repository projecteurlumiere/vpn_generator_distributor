class InstructionsController < ApplicationController
  def self.routes
    instructions = Instructions.instance.all.map do |_file_name, content|
      [
        content[:title], # instruction titles
      ]
    end.flatten

    instructions + ["Подключить VPN", "К выбору устройства"]
  end

  def call
    if ["Подключить VPN", "К выбору устройства"].any?(message.text)
      msg = <<~TXT
        Вот список доступных инструкций:
      TXT

      reply_with_instructions(msg)
      return
    end

    if instruction_name = Instructions.instance.instruction_name_by_title(message.text)
      current_user.update(state: "#{self.class.name}|#{instruction_name}|key|false")
    end

    if current_user.state.nil?
      reply_with_instructions("Такой команды нет.\nПохоже, вы потеряли инструкции. Вот они:")
      return
    end

    @controller, @instruction_name, @step, @key_reserved = current_user.state_array

    if @step == "key"
      case message.text
      in "Мне нужен ключ"
        issue_key
        return
      in "У меня уже есть ключ"
        @step = 0
      else
        msg = <<~TXT
          Для работы VPN'а вам понадобится ключ, который мы выдаём.
          Число таких ключей ограничено, но мы стараемся помочь всем.
          Если вы не уверены, о чем идет речь, выбирайте "Мне нужен ключ"
        TXT
        reply_with_buttons(msg,
          [
            ["У меня уже есть ключ", "Мне нужен ключ"]
          ]
        )
        return
      end
    end

    @step = @step.to_i
    if message.text == "Назад"
      if @step - 1 <= 0
        msg = <<~TXT
          Вот список доступных инструкций:
        TXT
  
        reply_with_instructions(msg)
        return
      elsif @step > current_instruction[:steps].size
         raise RoutingError
      else
        @step -= 2
      end
    elsif @step - 1 >= 0 &&
       current_instruction[:steps][@step - 1][:actions].none?(message.text)
      raise RoutingError
    end

    if @step >= current_instruction[:steps].size
      current_user.update(state: nil)
      reply_success
      return
    end

    reply_instruction_step
  end

  private

  def current_instruction
    Instructions.instance[@instruction_name]
  end

  def reply_instruction_step
    current_step = current_instruction[:steps][@step]

    reply_with_buttons(
      current_step[:text],
      [
        *current_step[:actions].map { |a| [a] },
        ["Назад", "К выбору устройства", "Написать в поддержку"]
      ],
      photos: current_step[:images],
      parse_mode: "Markdown"
    )

    if current_step[:issue_key] && @key_reserved
      upload_key(current_step[:issue_key])
    end

    @step += 1
    current_user.update(state: [@controller, @instruction_name, @step.to_i, @key_reserved].join("|"))
  end

  def reply_success
    current_user.update(about_received: true)
    reply("Ура! Очень рады, что все получилось ❤️")
    reply_slide(:about)
  end

  def reply_with_instructions(msg)
    reply_with_buttons(
      msg,
      [
        ["Вернуться в меню"],
        *Instructions.instance
                     .titles
                     .each_slice(3)
                     .to_a
      ]
    )
  end

  def reply_with_start_menu(msg = nil)
    reply_with_buttons(
      [msg, "Доступны следующие действия:"].compact.join("\n\n"),
      [
        ["Подключить VPN"],
        ["Правила"],
        ["О проекте"],
        ["Написать в поддержку"]
      ].compact
    )
  end

  def issue_key
    if current_user.too_many_keys?
      msg = <<~TXT
        Ошибка!
        У вас слишком много ключей. Возможно, вы хотели свериться с инструкцией не получая ключ?

        Вот доступные инструкции:
      TXT

      reply_with_instructions(msg)
    elsif current_user.config_reserved?
      reply("Ваш ключ уже зарезервирован для вас!")

      @key_reserved = true
      @step = 0
      reply_instruction_step
    else
      reply("Резервируем для вас место в нашей VPN сети. Это займёт около минуты. Если вы уверены, что что-то пошло не так, нажмите /start")

      case Key.issue(to: current_user)
      in :user_awaits_config
        reply("Мы уже резервируем для вас место. Пожалуйста, подождите", reply_markup: nil)
      in :keydesks_full
        reply_with_instructions("К сожалению, сейчас ключи закончились. Зайдите, пожалуйста, завтра.")
      in :keydesks_error
        reply_with_instructions("Что-то пошло во время создания конфигурации. Попробуйте ещё раз или позже.")
      in Key
        reply("Ключ успешно зарезервирован. Продолжайте следовать инструкции.")

        @key_reserved = true
        @step = 0
        reply_instruction_step
      end
    end
  end

  def upload_key(key_type)
    if key = current_user.keys_dataset.where { reserved_until >= Time.now }.first
      dir_path = "./tmp/vpn_configs/per_key/#{key.id}"
      file_path = Dir.glob(File.join(dir_path, "#{key_type}*")).first

      case key_type
      in "amnezia" | "wireguard"
        upload_file(file_path)
      in "outline" | "vless"
        reply(File.read(file_path), reply_markup: nil)
      end

      DB.transaction do
        key.update(desc: "Выдан для #{@instruction_name}", reserved_until: nil)
        current_user.update(about_received: false)
      end

      FileUtils.rm_rf(dir_path)
    else
      msg = <<~TXT
        Похоже, вы резервировали ключ в начале прохождения инструкции.
        К сожалению, срок, на который мы зарезервировали вам ключ уже прошёл.
        Попробуйте пройти инструкцию заново и запросить ключ в начале её прохождения.
      TXT

      reply(msg)
    end
  end
end
