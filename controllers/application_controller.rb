# base class for controllers
# offers controller-wide wrappers for tg api
class ApplicationController
  attr_reader :bot, :message, :chat_id, :tg_id

  def self.routes
    raise "#{__method__} method must be defined in the child class!"
  end

  def initialize(bot, message)
    @bot = bot
    @message = message

    if message.is_a?(Telegram::Bot::Types::CallbackQuery)
      @chat_id = message.message.chat.id
      @tg_id = message.from.id
    else
      @chat_id = message.chat.id
      @tg_id = message.from.id
    end
  end

  private

  # just a textual reply that removes keyboard/buttons altogether
  # usage:
  # reply("hello world!")
  def reply(text = nil, **opts)
    bot.api.send_message(chat_id:,
                         text:,
                         reply_markup: Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true),
                         **opts)
  end

  # replies with buttons, attached to the message (inline buttons)
  # usage:
  # reply_with_buttons("Here are your choices", { "Visible option text" => "Callback_info" } )
  def reply_with_inline_buttons(text, data_hash, **reply_opts)
    buttons = data_hash.map do |label, callback|
      Telegram::Bot::Types::InlineKeyboardButton.new(text: label, callback_data: callback)
    end

    reply_markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard: [buttons] # all buttons in one row; split into arrays for multiple rows
    )

    reply(text, reply_markup:, **reply_opts)
  end

  # replies with reply keyboard buttons that replace the user's text keyboard
  # usage:
  # reply_with_reply_keyboard("Pick one:", [
  #   ["Option 1", "Option 2"],
  #   ["Option 3"]
  # ])
  def reply_with_buttons(text, buttons, one_time_keyboard: false, resize_keyboard: true, **reply_opts)
    keyboard = buttons.map do |row|
      row.map { |label| Telegram::Bot::Types::KeyboardButton.new(text: label) }
    end

    reply_markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard:,
      one_time_keyboard:,
      resize_keyboard:
    )

    reply(text, reply_markup:, **reply_opts)
  end

  def first_name
    message.from.first_name
  end

  def current_user
    @current_user ||= User.find(tg_id:) || User.create(tg_id:)
  end

  def reply_with_start_menu(message)
    buttons = if current_user && current_user.keys.any?
                [
                  ["Новый ключ", "Управление ключами"],
                  ["Инструкции"]
                ]
              else
                [
                  ["Новый ключ", "Инструкции"]
                ]
              end


    reply_with_buttons(message, buttons)
  end
end
