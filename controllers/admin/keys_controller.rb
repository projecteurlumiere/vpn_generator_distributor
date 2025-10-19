class Admin::KeysController < Admin::BaseController  # chat_id is the one the file is sent to
  def create(user_id, configs = Key::VALID_CONFIGS)
    configs = YAML.load(configs) if configs.is_a?(String)

    if user = User[user_id]
      reply("Выдаём ключ пользователю #{user.tg_id}. Нужно подождать.")
      key = Key.issue(to: user)

      dir_path = "./tmp/vpn_configs/per_key/#{key.id}"

      config_files = Dir.glob("#{dir_path}/*")
      config_files.each_with_index do |file_path, i|
        filename = File.basename(file_path, File.extname(file_path))
        next if configs.none?(filename)

        if chat_id == $admin_chat_id
          support_request = SupportRequest.where(user_id: user_id)
                                          .where(status: :open)
                                          .first

          upload_file(file_path, "Ваш файл настроек")
        else
          upload_file(file_path, "VPN-файл #{filename} для пользователя #{user.id}")
        end
      end

      key.update(desc: "Выдан администратором #{[first_name, last_name].compact.join(" ")}", reserved_until: nil)
      FileUtils.rm_rf(dir_path)

      reply_with_inline_buttons("Ключ выдан успешно\n", [
        admin_menu_inline_button,
        { "К ключам пользователя" => callback_name(Admin::UsersController, "user_menu", user.id) }
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
          { "К ключам пользователя" => callback_name(Admin::UsersController, "user_menu", key.user.id) }
        ])
      in false
        reply_with_inline_buttons("Не получилось удалить ключ #{key.id}", [
          admin_menu_inline_button,
          { "К ключам пользователя" => callback_name(Admin::UsersController, "user_menu", key.user.id) }
        ])
      end
    else
      reply_with_inline_buttons("Такого ключа не существует", [
        admin_menu_inline_button
      ])
    end
  end
end
