# frozen_string_literal: true

module Admin::KeydesksController::UpdateKeydesk
  def edit
    current_user.update(state: [self.class.name, "edit_keydesk", "name"].join("|"))
    reply("Введите имя ключницы")
  end

  private

  def update_keydesk(state)
    msg = message.text.strip

    case state.drop(2)
    in ["name", *] if (kd = Keydesk.first(name: msg))
      new_state = state << kd.id
      new_state[2] = "menu"
      current_user.update(state: new_state.join("|"))
      reply_with_buttons("Доступные действия для ключницы `#{msg}`:",[
        ["Изменить имя или число ключей"],
        (["Удалить"] if kd.keys_dataset.count == 0)
      ].compact)
    in ["name", *]
      reply("Нет такой ключницы")
    in ["menu", *] if msg == "Удалить"
      new_state = state.dup
      new_state[2] = "destroy_confirm"

      kd = Keydesk.first(id: state[3])
      current_user.update(state: new_state.join("|"))
      reply_with_buttons(
        "Точно ли вы хотите удалить ключницу #{kd.name}?\nВсе записи о ключах в базе данных бота будут удалены!",
        [["Да, удалить", "Нет, не удалять"]]
      )
    in ["destroy_confirm", *] if msg == "Да, удалить"
      kd = Keydesk[state[3]]
      kd.keys_dataset.delete
      kd.destroy
      reply("Ключница #{kd.name} удалена")
      current_user.update(state: nil)
      restart
    in ["destroy_confirm", *] if msg == "Нет, не удалять"
      current_user.update(state: nil)
      index
    in ["menu", *] if msg == "Изменить имя или число ключей"
      new_state = state.dup
      new_state[2] = "edit_name"
      current_user.update(state: new_state.join("|"))

      reply_with_buttons("Введите новое имя", [["Оставить прежнее"]])
    in ["edit_name", *] if msg == "Оставить прежнее"
      new_state = state.dup
      new_state[2] = "edit_max_keys"
      current_user.update(state: new_state.join("|"))

      reply_with_buttons("Введите новое максимальное число пользователей для ключницы (целое число)", [["Оставить прежнее"]])
    in ["edit_name", *] if msg.size > 13
      reply("Новое имя не может быть длиннее 13 символов.", reply_markup: nil)
    in ["edit_name", *] if (kd = Keydesk.first(name: msg))
      reply("Такое имя уже занято", reply_markup: nil)
    in ["edit_name", *]
      Keydesk.first(id: state[3]).update(name: msg)
      reply("Имя обновлено")

      new_state = state.dup
      new_state[2] = "edit_max_keys"

      current_user.update(state: new_state.join("|"))
      reply_with_buttons("Введите новое максимальное число пользователей для ключницы (целое число)", [["Оставить прежнее"]])
    in ["edit_max_keys", *] if msg == "Оставить прежнее"
      reply("Редактирование окончено")
      current_user.update(state: nil)
      index
    in ["edit_max_keys", *] unless msg.match?(/\A\d/)
      reply("Введите целое число", reply_markup: nil)
    in ["edit_max_keys", *] if msg.to_i > Keydesk::MAX_USERS
      reply("Число не должно превышать #{Keydesk::MAX_USERS}", reply_markup: nil)
    in ["edit_max_keys", *]
      Keydesk.first(id: state[3]).update(max_keys: msg)
      reply("Максимальное число ключей обновлено")
      reply("Редактирование окончено")
      current_user.update(state: nil)
      index
    else
      raise RoutingError
    end
  end
end
