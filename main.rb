require "dotenv/load" if ENV["ENV"] != "production"

require "logger"
LOGGER = Logger.new((ENV["ENV"] == "production" ? "tmp/log.log" : $stdout))

require_relative "db/init"
require_relative "initializers/all"

require "telegram/bot"

TOKEN = ENV["TELEGRAM_TOKEN"].freeze

Routes.instance.build!

def dispatch_controller(bot, message)
  case message
  in Telegram::Bot::Types::Message
    type = :command
    method = :call

    if message.text.start_with?("/")
      message.text.split(" ") => [key, *args] 
    else
      key = message.text
      args = []
    end
  # in Telegram::Bot::Types::CallbackQuery
  #   raise "Handling CallbackQuery type of messages is not implemented!"
  #   type = :callback
  #   message.data.split("_") => [key, method, *args]
  end

  klass = Routes.instance[type][key]
  klass.new(bot, message).send(method, *args)
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
