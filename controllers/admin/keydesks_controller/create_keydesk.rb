# frozen_string_literal: true

module Admin::KeydesksController::CreateKeydesk
  def new
    current_user.update(state: [self.class.name, "new_keydesk", "name"].join("|"))
    reply("Введите имя ключницы")
  end

  private

  def create_keydesk(state)
    msg = message.text.strip

    case state.drop(1)
    in ["name", *] if Keydesk.first(name: msg)
      reply("Ключница с таким именем уже существует")
    in ["name", *] if msg.size > 13
      reply("Имя ключницы не должно превышать 13 символов")
    in ["name", *]
      new_state = state << msg
      new_state[2] = "max_keys"
      current_user.update(state: new_state.join("|"))
      reply("Введите максимальное число пользователей для ключницы (целое число)")
    in ["max_keys", *] unless msg.match?(/\A\d/)
      reply("Укажите целое число")
    in ["max_keys", *] if msg.to_i > Keydesk::MAX_USERS
      reply("Число не должно превышать #{Keydesk::MAX_USERS}")
    in ["max_keys", *]
      new_state = state << msg
      new_state[2] = "ss_link"
      current_user.update(state: new_state.join("|"))
      reply("Отправьте ссылку для подключения к ключнице")
    in ["ss_link", *] if Keydesk.first(ss_link: msg)
      reply("Ключница с такой ссылкой уже существует")
    in ["ss_link", name, max_keys]
      Keydesk.create(name:, max_keys:, ss_link: msg)
      current_user.update(state: nil)
      reply("Ключница добавлена")
      self.restart
    else
      raise RoutingError
    end
  end
end
