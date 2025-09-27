class Admin::KeysController < ApplicationController
  def self.routes
    []
  end

  def destroy(id)
    if (key = Key[id])
      key.destroy
      reply_with_inline_buttons("Ключ удалён успешно\n", [
        { "К ключам пользователя" => callback_name(Admin::UsersController, "user_menu", key.user_id) },
        admin_menu_inline_button
      ])
    else
      reply("Такого ключа не существует", [
        admin_menu_inline_button
      ])
    end
  end
end
