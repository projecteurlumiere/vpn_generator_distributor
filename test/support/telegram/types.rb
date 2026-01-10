module Telegram
  module Bot
    module Types
      Message              = Struct.new(:text, :from, :chat, :reply_to_message)
      CallbackQuery        = Struct.new(:data, :from, :message)
      ChatMemberUpdated    = Struct.new(:status, :from, :chat)
      InlineKeyboardButton = Struct.new(:text, :callback_data)
      InlineKeyboardMarkup = Struct.new(:inline_keyboard)
      KeyboardButton       = Struct.new(:text)
      LinkPreviewOptions   = Struct.new(:is_disabled)
      ReplyKeyboardMarkup  = Struct.new(:keyboard, :one_time_keyboard, :resize_keyboard, :is_persistent, :input_field_placeholder)
      ReplyKeyboardRemove  = Struct.new(:remove_keyboard)
    end
  end
end
