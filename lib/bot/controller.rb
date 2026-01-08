# frozen_string_literal: true

class Bot::Controller
  attr_reader :bot, :message, :chat_id, :message_thread_id, :tg_id

  def self.routes
    []
  end

  def initialize(bot, message)
    @bot = bot
    @message = message

    @tg_id = message.from.id

    if message.is_a?(Telegram::Bot::Types::CallbackQuery)
      @chat_id = message.message.chat.id
      @message_thread_id = message.message&.message_thread_id
    else
      @chat_id = message.chat.id
      @message_thread_id = message.reply_to_message&.message_thread_id
    end
  end

  private

  def current_user
    @current_user ||= User.find(tg_id:) || User.create(tg_id:)
  end

  #
  # Replies handling
  #

  # just a textual reply that removes keyboard/buttons altogether
  # usage:
  # reply("hello world!")
  def reply(text = nil, **opts)
    opts[:reply_markup] = Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true) unless opts.key?(:reply_markup)

    if (photos = opts.delete(:photos)) && photos.any?
      if photos.size == 1
        bot.api.send_photo(
          chat_id:,
          message_thread_id:,
          photo: photos.first,
          caption: text,
          **opts
        )
      else
        # Send multiple images as media group
        media = photos.map do |photo|
          { type: "photo", media: photo }
        end

        bot.api.send_media_group(
          chat_id:,
          message_thread_id:,
          media:,
          **opts
        )

        bot.api.send_message(
          chat_id:,
          message_thread_id:,
          text:,
         **opts
         )
      end
    else
      bot.api.send_message(
        chat_id:,
        message_thread_id:,
        text:,
        **opts
      )
    end
  end

  # replies with buttons, attached to the message (inline buttons)
  # usage:
  # reply_with_inline_buttons("Here are your choices", { "Visible option text" => "Callback_info" })
  def reply_with_inline_buttons(text, data, **reply_opts)
    data = [data] unless data.is_a?(Array)

    inline_keyboard = data.map do |row|
      row.map do |label, callback|
        Telegram::Bot::Types::InlineKeyboardButton.new(text: label, callback_data: callback)
      end
    end

    reply_markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(
      inline_keyboard:
    )

    reply(text, reply_markup:, **reply_opts)
  end

  # replies with reply keyboard buttons that replace the user's text keyboard
  # usage:
  # reply_with_buttons("Pick one:", [
  #   ["Option 1", "Option 2"],
  #   ["Option 3"]
  # ])
  def reply_with_buttons(text, buttons, one_time_keyboard: false,
                                        resize_keyboard: true,
                                        is_persistent: true,
                                        input_field_placeholder: "Выберите кнопку",
                                        **reply_opts)
    keyboard = buttons.map do |row|
      row.map { |label| Telegram::Bot::Types::KeyboardButton.new(text: label) }
    end

    keyboard_opts = {
      keyboard:,
      one_time_keyboard:,
      resize_keyboard:,
      is_persistent:,
      input_field_placeholder:
    }.compact
    reply_markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(**keyboard_opts)

    reply(text, reply_markup:, **reply_opts)
  end

  def edit_message(text,
                   buttons = [],
                   chat_id: message.message.chat.id,
                   message_id: message.message.message_id,
                   **opts)
    if buttons.to_a.any?
      opts[:reply_markup] = Telegram::Bot::Types::InlineKeyboardMarkup.new(
        inline_keyboard: buttons.map do |btn|
          btn.map do |text, callback_data|
            Telegram::Bot::Types::InlineKeyboardButton.new(text: text, callback_data: callback_data)
          end
        end
      )
    end

    bot.api.edit_message_text(text:, chat_id:, message_id:, **opts)
  end

  # name - Symbol
  def reply_slide(name, **args)
    slide = Slides.instance[name]
    reply_with_buttons(slide[:text], [slide[:actions]], photos: slide[:images], parse_mode: "Markdown", **args)
  end

  def repeat_message(chat_id:, message_thread_id: nil)
    args = {
      chat_id:,
      message_thread_id:
    }

    if message.text
      bot.api.send_message(text: message.text, **args)
    elsif message.photo
      file_id = message.photo.last.file_id
      bot.api.send_photo(photo: file_id, caption: message.caption, **args)
    elsif message.document
      bot.api.send_document(document: message.document.file_id, caption: message.caption, **args)
    elsif message.audio
      bot.api.send_audio(audio: message.audio.file_id, caption: message.caption, **args)
    elsif message.voice
      bot.api.send_voice(voice: message.voice.file_id, caption: message.caption, **args)
    elsif message.video
      bot.api.send_video(video: message.video.file_id, caption: message.caption, **args)
    elsif message.sticker
      bot.api.send_sticker(sticker: message.sticker.file_id, **args)
    else
      msg = "Это сообщение не может быть перенаправлено через бота."
      bot.api.send_message(text: msg, chat_id: self.chat.id, message_thread_id: self.message_thread_id)
    end
  end

  #
  # Files handling
  #

  def download_attachment(file_id, dest_path)
    file = bot.api.get_file(file_id:)
    file_path = file.file_path
    file_url = "https://api.telegram.org/file/bot#{Bot::TOKEN}/#{file_path}"

    FileUtils.mkdir_p(File.dirname(dest_path))
    File.open(dest_path, "wb") do |f|
      f.write(Net::HTTP.get(URI(file_url)))
    end

    dest_path
  end

  def upload_file(path, message = nil, **opts)
    file = File.open(path)
    upload = Faraday::UploadIO.new(file, "text/plain", File.basename(file))

    bot.api.send_document(
      chat_id: chat_id,
      document: upload,
      caption: message,
      **opts
    )
  ensure
    file.close
  end
end
