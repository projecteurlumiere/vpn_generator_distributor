class Admin::UsersController < Admin::BaseController
  include Admin::UserManagement

  def call
    @controller, @state, @target_id = current_user.state_array

    case @state
    in "find_user"
      handle_find_user
    else
      raise RoutingError
    end
  end

  def find_user
    current_user.update(state: [self.class.name, "find_user"].join("|"))
    reply_with_inline_buttons("Введите id пользователя", [
      admin_menu_inline_button
    ])
  end

  def menu
    msg = <<~TXT
      Возможные действия с пользователями
    TXT

    reply_with_inline_buttons(msg, [
      admin_menu_inline_button,
      { "Ключи пользователя" => callback_name("user_keys") }
    ])
  end

  private

  def handle_find_user
    @target_id = message.text.to_i

    if target_user
      current_user.update(state: [self.class.name, "menu", @target_id].join("|"))
      user_menu
    else
      reply("Пользователь с id `#{@target_id}` не найден", reply_markup: nil)
    end
  end
end
