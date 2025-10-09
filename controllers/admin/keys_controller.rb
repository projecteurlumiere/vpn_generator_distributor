class Admin::KeysController < ApplicationController
  def self.routes
    []
  end

  def create(user_id)
    if user = User[user_id]
      reply("Выдаём ключ пользователю #{user.tg_id}. Нужно подождать.")
      key = Key.issue(to: user)

      dir_path = "./tmp/vpn_configs/per_key/#{key.id}"

      configs = Dir.glob("#{dir_path}/*")

      configs.each_with_index do |file_path, i|
        filename = File.basename(file_path, File.extname(file_path))
        upload_file(file_path, "VPN-файл #{filename} для пользователя #{user.tg_id}")
      end

      key.update(desc: "Выдан администратором", reserved_until: nil)
      FileUtils.rm_rf(dir_path)

      reply_with_inline_buttons("Ключ выдан успешно\n", [
        admin_menu_inline_button,
        { "К ключам пользователя" => callback_name(Admin::UsersController, "user_menu", user.tg_id) }
      ])
    else
      reply_with_inline_buttons("Такого пользователя не существует", [
        admin_menu_inline_button
      ])
    end
  end

  def destroy(id)
    if (key = Key[id]) && key.destroy
      case key.destroy
      in :pending_destroy
        reply("Ключ #{key.id} в процессе удаления", reply_markup: nil)
      in true
        reply_with_inline_buttons("Ключ #{key.id} удалён успешно\n", [
          admin_menu_inline_button,
          { "К ключам пользователя" => callback_name(Admin::UsersController, "user_menu", key.user.tg_id) }
        ])
      in false
        reply_with_inline_buttons("Не получилось удалить ключ #{key.id}", [
          admin_menu_inline_button,
          { "К ключам пользователя" => callback_name(Admin::UsersController, "user_menu", key.user.tg_id) }
        ])
      end
    else
      reply_with_inline_buttons("Такого ключа не существует", [
        admin_menu_inline_button
      ])
    end
  end
end
