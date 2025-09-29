class Admin::UsersController < ApplicationController
  def self.routes
    []
  end

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
    reply_with_inline_buttons("Введите tg_id пользователя", [
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

  def user_menu(tg_id = nil)
    if tg_id.nil?
      @controller, @state, @target_id = current_user.state_array
    else
      @target_id = tg_id
    end

    if target_user.nil?
      reply("Пользователь с tg_id #{@target_id} не найден")
      menu
      return
    end

    msg = <<~TXT
      Возможные действия для пользователя #{target_user.tg_id}
    TXT

    reply_with_inline_buttons(msg, [
      admin_menu_inline_button,
      { "Добавить ключ" => callback_name(Admin::KeysController, "create", target_user.id) },
      { "Управлять ключами" => callback_name("user_keys", target_user.tg_id) }
    ])
  end

  def user_keys(tg_id = nil)
    if tg_id.nil?
      @controller, @state, @target_id = current_user.state_array
    else
      @target_id = tg_id
    end

    if target_user.nil?
      reply("Пользователь с tg_id #{@target_id} не найден")
      menu
      return
    end

    keys = target_user.keys_dataset
                      .eager(:keydesk)
                      .order(Sequel.desc(:created_at))
                      .all

    lines = Concurrent::Hash.new

    threads = keys.map do |key|
      Thread.new do
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
          status = "❌"
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
    end

     actions = keys.map do |key|
      { "Удалить ключ #{key.id}" => callback_name(Admin::KeysController, "destroy", key.id) }
    end

    threads.map(&:join)

    if lines.any?
      msg = "Пользователю `#{@target_id}` принадлежат следующие ключи:\n\n"
      msg << keys.map { |key| "#{lines[key.id]}\n---" }.join("\n")
    else
      msg = "У пользователя `#{@target_id}` нет ключей"
    end

    reply_with_inline_buttons(msg, [
      { "К настройкам пользователя" => callback_name("user_menu", @target_id) },
      *actions
    ])
  end

  private

  def target_user
    @target_user ||= User.where(tg_id: @target_id).first
  end

  def handle_find_user
    @target_id = message.text.to_i

    if target_user
      current_user.update(state: [self.class.name, "menu", @target_id].join("|"))
      user_menu
    else
      reply("Пользователь с tg_id `#{@target_id}` не найден", reply_markup: nil)
    end
  end
end
