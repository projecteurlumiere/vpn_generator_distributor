# frozen_string_literal: true

module Admin::UserManagement
  def user_menu(id = nil)
    populate_target_id(id)

    msg = <<~TXT
      Возможные действия для пользователя #{target_user.id}
    TXT

    actions = user_menu_actions

    reply_with_actions(msg, [
      *actions,
      { "Управлять ключами" => callback_name("user_keys", target_user.id) }
    ])
  end

  def user_keys(id = nil)
    populate_target_id(id)

    keys = target_user.keys_dataset
                      .eager(:keydesk)
                      .order(Sequel.desc(:created_at))
                      .all
    lines = {}

    tasks = keys.map do |key|
      Async { request_key_info(key, lines) }
    end

    actions = keys.map do |key|
      { "Удалить ключ #{key.id}" => callback_name(Admin::KeysController, "destroy", key.id) }
    end

    tasks.map(&:wait)

    if lines.any?
      msg = "Пользователю `#{@target_id}` принадлежат следующие ключи:\n\n"
      msg << keys.map { |key| "#{lines[key.id]}\n---" }.join("\n")
    else
      msg = "У пользователя `#{@target_id}` нет ключей"
    end

    reply_with_actions(msg, [
      { "К настройкам пользователя" => callback_name("user_menu", @target_id) },
      *actions
    ])
  end

  private

  def populate_target_id(id)
    if id.nil? && self.class == Admin::UsersController
      @controller, @state, @target_id = current_user.state_array
      raise if [Admin::UsersController, Admin::SupportRequestsController].map(&:name).none?(@controller)
    elsif id.nil?
      raise "Cannot find ID for user management"
    else
      @target_id = id
    end

    if target_user.nil?
      reply("Пользователь с id #{@target_id} не найден")
      menu
      raise "Cannot find user with #{@target_id} for user management"
    end
  end

  def target_user
    @target_user ||= User.where(id: @target_id).first
  end

  def user_menu_actions
    case self
    in Admin::UsersController
      [
        admin_menu_inline_button,
        { "Добавить ключ" => callback_name(Admin::KeysController, "create", target_user.id) },
      ]
    in Admin::SupportRequestsController
      Key::VALID_CONFIGS.map do |config|
        { "Добавить #{config}" => callback_name(Admin::KeysController, "create", target_user.id, JSON.dump([config])) }
      end
    end
  end

  def request_key_info(key, lines)
    begin
      user_hash = key.keydesk.users.find { |user| key.keydesk_username == user["UserName"] }
      status =  case user_hash["Status"]
                in "black"
                  "⚫️"
                in "green"
                  "🟢"
                in "gray"
                  "⚪️"
                else
                  user_hash["Status"]
                end

    rescue StandardError => e
      LOGGER.error([
        "Error fetching user status from keydesk.",
        "Key ID: #{key.id}, Keydesk: #{key.keydesk.name}, Keydesk Username: #{key.keydesk_username}",
        "Exception: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
      ].join("\n"))
      status = "❓"
    end

    lines[key.id] = [
      "Статус: #{status}",
      "ID: #{key.id}",
      "Ключница: #{key.keydesk.name}",
      "Имя в ключнице: #{key.keydesk_username}",
      "Описание: #{key.desc}",
      "Создан: #{key.created_at.strftime('%Y-%m-%d %H:%M')}"
    ].join("\n")
  end

  def reply_with_actions(*args, **kwargs)
    method = case self
             in Admin::UsersController
               :reply_with_inline_buttons
             in Admin::SupportRequestsController
               :edit_message
             end

    send(method, *args, **kwargs)
  rescue Telegram::Bot::Exceptions::ResponseError => e
    raise unless e.message.match?(/message is not modified/i)
  end
end
