require "dotenv/load" if ENV["ENV"] != "production"

require "logger"
LOGGER = Logger.new((ENV["ENV"] == "production" ? "tmp/log.log" : $stdout))

require_relative "db/init"
require_relative "initializers/all"

require "telegram/bot"

TOKEN = ENV["TELEGRAM_TOKEN"].freeze

ROUTES = {
  command: {
    "/start" => StartController,
    "Всё понятно, спасибо" => StartController,
    "Не хочу ничего удалять, спасибо" => StartController,
    "/stop" => StopController,
    "Новый ключ" => KeysController,
    "Управление ключами" => KeysController,
    "Удалить ключ" => KeysController
  },
  callback: {
    "key" => KeysController
  }
}.freeze

def dispatch_controller(bot, message)
  if message.is_a?(Telegram::Bot::Types::CallbackQuery)
    type = :callback
    message.data.split("_") => [key, method, *args]
  elsif message.text
    type = :command
    method = :call
    key = message.text
    args = []
  end

  klass = ROUTES[type][key]
  klass&.new(bot, message)&.send(method, *args)
end

Telegram::Bot::Client.run(TOKEN) do |bot|
  bot.listen do |message|
    Thread.new do 
      dispatch_controller(bot, message)
    rescue StandardError => e
      ApplicationController.new(bot, message).send(:reply, "Что-то пошло не так.\nЕсли вы потерялись, вернуться можно нажав на /start")
      LOGGER.error "Unhandled error when processing request: #{e}\n#{e.full_message}"
      raise e
    end
  end
end


# /start
# # If no keys:
# # Welcome!
# # Получить ключ || Инструкции

# # If there are keys
# # Новый ключ || Управление ключами || Инструкции

# Получить ключ
# # Если мест недостаточно:
# # # Сейчас свободных мест нет (возвращаем назад)
# # Если больше 5 ключей на юзере
# # # У вас слишком много ключей: вы можете попробовать удалить и создать новый
# # Если норм, хотите ввести персональное имя для ключа? (персональная заметка: "ВПН для ноутбука" или "для бабушки")
# # Выдать ключ
# # Инструкции