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
    current_user.update(state: [self.class.name, "find_user"])
    reply_with_inline_buttons("Введите tg_id пользователя", [
      { "Назад" => callback("menu") }
    ])
  end

  def menu
    msg = <<~TXT
      Возможные действия с пользователями
    TXT

    reply_with_inline_buttons(msg, [
      admin_menu_inline_button,
      { "Ключи пользователя" => callback("user_keys") }
    ])
  end

  def user_menu(id = nil)
    if id.nil?
      @controller, @state, @target_id = current_user.state_array
    else
      @target_id = id
    end

    if target_user.nil?
      reply("Пользователь с tg_id #{@target_id} не найден")
      menu
      return
    end

    keys = target_user.keys_dataset.eager(:keydesk).all

    lines = Concurrent::Hash.new

    threads = keys.map do |key|
      Thread.new do
        begin
          user_hash = key.keydesk.users.find { |user| target_user.keydesk_username == user["UserName"] }
          status =  case user_hash["Status"]
                    in "green"
                      "🟢"
                    in "gray"
                      "⚪️"
                    else
                      user_hash["Status"]
                    end

        rescue StandardError
          status = "❌"
        end


        lines[key.id] = [
          "Статус: #{status}",
          "ID: #{key.id}",
          "Ключница: #{key.keydesk.name}",
          "Имя в ключнице: #{key.keydesk_username}",
          "Описание: #{key.desc}",
          "Создан: #{key.created_at.strftime('%Y-%m-%d')}"
        ].join("\n")
      end
    end


    actions = keys.map do |key|
      { "Удалить ключ" => callback_name(Admin::KeysController, "destroy", key.id) }
    end

    threads.map(&:join)

    if lines.any?
      msg = "Пользователю `#{@target_id}` принадлежат следующие ключи:\n\n"
      msg << lines.sort_by { |k, _| k }.map { |_, line| "#{line}\n---" }.join("\n")
    else
      msg = "У пользователя `#{@target_id}` нет ключей"
    end

    reply_with_inline_buttons(msg, [
      admin_menu_inline_button,
      *actions
    ])
  end

  private

  def target_user
    @target_user ||= User[@target_id]
  end

  def handle_find_user
    @target_id = message.text.to_i

    if target_user
      current_user.update(state: [self.class.name, "menu", @target_id])
      user_menu
    else
      reply("Пользователь с tg_id `#{@target_id}` не найден", reply_markup: nil)
    end
  end
end
