class Admin::KeysController < Admin::BaseController  # chat_id is the one the file is sent to
  def create(user_id, configs = Key::VALID_CONFIGS)
    configs = YAML.load(configs) if configs.is_a?(String)

    if user = User[user_id]
      reply(with_emoji("Выдаём ключ пользователю #{user.id}. Нужно подождать."))

      case key = Key.issue(to: user)
      in :keydesks_full
        msg = with_emoji("Свободных мест нет")
        reply(msg)
      in :keydesks_error
        msg = with_emoji("Что-то пошло во время создания конфигурации. Попробуйте ещё раз или позже.")
        reply(msg)
      in Key
        dir_path = "./tmp/vpn_configs/per_key/#{key.id}"

        config_files = Dir.glob("#{dir_path}/*")
        config_files.each_with_index do |file_path, i|
          filename = File.basename(file_path, File.extname(file_path))
          next if configs.none?(filename)

          if chat_id == Bot::ADMIN_CHAT_ID
            support_request = SupportRequest.where(user_id: user_id)
                                            .where(status: [0, 1])
                                            .first
            support_request.set_open!(bot)
            upload_file(file_path, "Ваш файл настроек", chat_id: support_request.chat_id)
          else
            upload_file(file_path, "VPN-файл #{filename} для пользователя #{user.id}")
          end
        end

        desc = message_thread_id ? "Выдан администратором" : "Выдан волонтёром"  
        desc = "#{desc} #{[first_name, last_name].compact.join(" ")}"

        key.update(desc:, reserved_until: nil)
        FileUtils.rm_rf(dir_path)

        reply_with_inline_buttons(with_emoji("Ключ выдан успешно\n"), [
          admin_menu_inline_button,
          { "К ключам пользователя" => callback_name(Admin::UsersController, "user_menu", user.id) }
        ])
      end
    else
      reply_with_inline_buttons("Такого пользователя не существует", [
        admin_menu_inline_button
      ])
    end
  end

  def destroy(id)
    if (key = Key[id]) && (res = key.destroy)
      case res
      in :pending_destroy
        msg = with_emoji("Ключ #{key.id} в процессе удаления")
        reply(msg, reply_markup: nil)
      in Key
        msg = with_emoji("Ключ #{key.id} удалён успешно")
        reply_with_inline_buttons(msg, [
          admin_menu_inline_button,
          { "К ключам пользователя" => callback_name(Admin::UsersController, "user_menu", key.user.id) }
        ])
      in false
        msg = with_emoji("Не получилось удалить ключ #{key.id}")
        reply_with_inline_buttons(msg, [
          admin_menu_inline_button,
          { "К ключам пользователя" => callback_name(Admin::UsersController, "user_menu", key.user.id) }
        ])
      end
    else
      msg = with_emoji("Такого ключа не существует")
      reply_with_inline_buttons(msg, [
        admin_menu_inline_button
      ])
    end
  end

  private

  def reply_with_inline_buttons(*args, **kwargs)
    if message_thread_id
      reply(args[0], **kwargs)
    else
      super
    end
  end

  def message_thread_id
    message.message.message_thread_id rescue nil
  end

  def with_emoji(msg)
    message_thread_id ? "🤖: #{msg}" : msg
  end
end
