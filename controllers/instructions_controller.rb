# frozen_string_literal: true

class InstructionsController < ApplicationController
  def self.routes
    instructions = Instructions.instance.all.map do |_filename, content|
      [content[:title]]
    end.flatten

    instructions + ["Подключить VPN", "Принимаю правила", "К выбору устройства"]
  end

  def call
    return if requests_instruction_menu?

    set_initial_instruction # if requested
    return if no_instruction_found?

    @controller, @instruction_name, @step, @key_reserved = current_user.state_array

    return if show_rules? ||
              manages_key?

    @step = @step.to_i
    return if count_step_backwards! ||
              invalid_forward_step_action! ||
              instruction_is_over?

    reply_instruction_step
  end

  private

  def current_instruction
    Instructions.instance[@instruction_name]
  end

  def requests_instruction_menu?
    if ["Подключить VPN", "К выбору устройства"].any?(message.text)
      reply_with_instructions("Выберите ваше устройство")
      true
    end
  end

  def set_initial_instruction
    if instruction_name = Instructions.instance.instruction_name_by_title(message.text)
      current_user.update(state: "#{self.class.name}|#{instruction_name}|rules|false")
    end
  end

  def no_instruction_found?
    if current_user.state.nil?
      reply_with_instructions("Такой команды нет.\nПохоже, вы потеряли инструкции. Вот они:")
      true
    end
  end

  def show_rules?
    return unless @step == "rules"

    current_user.update_state!(self.class.name, @instruction_name, "key", "false")

    # we have to do it manually to prepend an action
    slide = Slides.instance[:rules]
    actions = [["Принимаю правила"], ["Назад", *slide[:actions].drop(1)]]
    reply_with_buttons(slide[:text], actions, photos: slide[:images], parse_mode: "Markdown")

    true
  end

  def manages_key?
    return unless @step == "key"

    case message.text
    in "Назад"
      reply_with_instructions("Выберите ваше устройство")
    in "Мне нужен ключ"
      issue_key
      return true
    in "У меня уже есть ключ"
      @step = 0
    in "Принимаю правила"
      msg = <<~TXT
        Для работы VPN'а вам понадобится ключ, который мы выдаём.
        Число таких ключей ограничено, но мы стараемся помочь всем.

        Если вы не знаете, какой из вариантов выбрать, выберите «мне нужен ключ»
      TXT
      reply_with_buttons(msg,
        [
          ["Мне нужен ключ", "У меня уже есть ключ"]
        ]
      )
      return true
    end

    false
  end

  def count_step_backwards!
    if message.text == "Назад"
      if @step - 1 <= 0
        msg = <<~TXT
          Выберите ваше устройство
        TXT

        reply_with_instructions(msg)
        return true
      elsif @step > current_instruction[:steps].size
        raise RoutingError
      else
        @step -= 2
      end

      false
    end
  end

  def invalid_forward_step_action!
    return if message.text == "Назад"

    if @step - 1 >= 0 && current_instruction[:steps][@step - 1][:actions].none?(message.text)
      raise RoutingError
    end
  end

  def instruction_is_over?
    if @step >= current_instruction[:steps].size
      current_user.update(state: nil)
      reply_success
      return true
    end
  end

  def reply_instruction_step
    current_step = current_instruction[:steps][@step]
    before_issuing_key = @step < current_instruction[:steps].find_index { it[:issue_key] }

    reply_with_buttons(
      current_step[:text],
      [
        *current_step[:actions].map { |a| [a] },
        [
          "Назад",
          ("К выбору устройства" if before_issuing_key),
          "Написать в поддержку"
        ].compact
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
    reply("Ура! Очень рады, что все получилось ❤️", reply_markup: nil)
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
        У вас слишком много ключей.
        Мы выдаём не более #{User::MAX_KEYS} ключей в одни руки.
        Это необходимо, чтобы как можно большее количество людей получило доступ к свободному интернету.

        Если вы хотите получить ключ для своих близких, расскажите им об этом боте, чтобы они сами обратились к нам.

        А еще вы можете пройти инструкцию без получения ключа. Для этого выберите ваше устройство:
      TXT

      reply_with_instructions(msg)
    elsif current_user.config_reserved?
      @key_reserved = true
      @step = 0
      reply_instruction_step
    else
      msg = <<~TXT
        Нам необходимо зарезервировать для вас ключ на нашем сервере.
        Пожалуйста, подождите. Это займёт около минуты.

        Если вы не получили ответ в течение пары минут, нажмите /start
      TXT
      reply(msg)

      case Key.issue(to: current_user)
      in :user_awaits_config
        reply("Пожалуйста, подождите ещё немного.", reply_markup: nil)
      in :keydesks_full
        msg = <<~TXT
          К сожалению, сейчас свободных ключей нет.
          Новые ключи появляются регулярно, поэтому, чтобы получить VPN, попробуйте пройти инструкцию позже.
          Например, завтра
        TXT
        reply_with_instructions(msg)
      in :keydesks_error | :keydesks_offline
        msg = <<~TXT
          На сервере произошла непредвиденная ошибка. Попробуйте ещё раз или зайдите в другой день.

          Если проблема не решается, обратитесь в поддержку - это можно сделать в стартовом меню /start
        TXT
        reply_with_instructions(msg)
      in Key
        reply("Все приготовления выполнены! Продолжайте следовать инструкции")

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
