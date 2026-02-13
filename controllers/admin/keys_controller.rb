# frozen_string_literal: true

class Admin::KeysController < Admin::BaseController  # chat_id is the one the file is sent to
  def is_authorized?
    current_user.admin? || concerns_open_support_request?
  end

  def create(user_id, configs = Key::VALID_CONFIGS)
    configs = JSON.parse(configs) if configs.is_a?(String)

    if user = User[user_id]
      # To avoid fiber yield - is this still necessary?
      Async { reply(with_emoji("Выдаём ключ пользователю #{user.id}. Нужно подождать.")) }

      case key = Key.issue(to: user, skip_limit: current_user.admin?)
      in :keydesks_full
        msg = with_emoji("Свободных мест нет")
        reply(msg)
      in :keydesks_offline
        msg = with_emoji("Ключницы сейчас недоступны. Попробуйте через час или позже.")
        reply(msg)
      in :keydesks_error
        msg = with_emoji("Что-то пошло не так во время создания ключа. Попробуйте ещё раз или позже.")
        reply(msg)
      in :user_awaits_config
        msg = with_emoji("Пользователю уже выдаётся ключ. Нужно подождать.")
        reply(msg)
      in Key
        send_out_key(key, user, configs)
      end
    else
      reply_with_inline_buttons("Такого пользователя не существует", [
        admin_menu_inline_button
      ])
    end
  end

  def destroy(id)
    # To avoid fiber yield - is this still necessary?
    Async { reply(with_emoji("Удаляем ключ #{id}"), reply_markup: nil) }

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

  def with_emoji(msg)
    message_thread_id ? "🤖: #{msg}" : msg
  end

  def send_out_key(key, user, configs)
    dir_path = "./tmp/vpn_configs/per_key/#{key.id}"

    config_files = Dir.glob("#{dir_path}/*")
    config_files.each do |file_path|
      filename = File.basename(file_path, File.extname(file_path))
      next if configs.none?(filename)

      if chat_id == Bot::ADMIN_CHAT_ID
        support_request = SupportRequest.where(user_id: user.id)
                                        .where(status: [0, 1])
                                        .first
        support_request.set_open!(bot)
        upload_key(file_path, filename, msg: "Ваш ключ #{filename}:", chat_id: support_request.user.chat_id)
      else
        upload_key(file_path, filename, msg: "Ключ #{filename} для пользователя #{user.id}:", chat_id:)
      end
    end

    desc = message_thread_id ? "Выдан волонтёром" : "Выдан администратором"
    desc = "#{desc} #{[first_name, last_name].compact.join(" ")} (id #{current_user.id})"

    key.update(desc:, reserved_until: nil)
    FileUtils.rm_rf(dir_path)

    reply_with_inline_buttons(with_emoji("Ключ выдан успешно"), [
      admin_menu_inline_button,
      { "К ключам пользователя" => callback_name(Admin::UsersController, "user_menu", user.id) }
    ])
  end

  def upload_key(file_path, key_type, chat_id:, msg:)
    reply(msg, chat_id:, reply_markup: nil, message_thread_id: nil)

    case key_type
    in "amnezia" | "wireguard"
      upload_file(file_path, chat_id:, message_thread_id: nil)
    in "outline" | "vless"
      reply(File.read(file_path), reply_markup: nil, chat_id:, message_thread_id: nil)
    end
  end
end
