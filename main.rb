require "dotenv/load" if ENV["ENV"] != "production"

require "logger"
LOGGER = Logger.new((ENV["ENV"] == "production" ? "tmp/log.log" : $stdout))

require_relative "db/init"
require_relative "initializers/all"

require "telegram/bot"

$token = ENV["TELEGRAM_TOKEN"].freeze
$mutex = Mutex.new
def $mutex.sync
  $mutex.synchronize { yield }
end

Routes.instance.build!

Telegram::Bot::Client.run($token) do |bot|
  bot.listen do |message|
    Thread.new do 
      Routes.instance.dispatch_controller(bot, message)
    rescue StandardError => e
      ApplicationController.new(bot, message).send(:reply, "Что-то пошло не так.\nЕсли вы потерялись, вернуться можно нажав на /start", reply_markup: nil)
      LOGGER.error "Unhandled error when processing request: #{e}\n#{e.full_message}"
      raise e
    end
  end
end
