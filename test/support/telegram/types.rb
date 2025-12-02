
module Telegram
  module Bot
    module Types
      Message        = Struct.new(:text, :from, :chat, :reply_to_message)
      CallbackQuery  = Struct.new(:data, :from, :message)
      ChatMemberUpdated = Struct.new(:status, :from, :chat)
      InlineKeyboardButton = Struct.new(:text, :callback_data)
      InlineKeyboardMarkup = Struct.new(:inline_keyboard)
      KeyboardButton = Struct.new(:text)
      ReplyKeyboardMarkup = Struct.new(:keyboard, :one_time_keyboard, :resize_keyboard)
      ReplyKeyboardRemove = Struct.new(:remove_keyboard)
      # add other stubs as you hit errors in tests
    end
  end
end
