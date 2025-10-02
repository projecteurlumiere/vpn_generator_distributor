require "dotenv/load" if ENV["ENV"] != "production"

require "logger"
LOGGER = Logger.new((ENV["ENV"] == "production" ? "tmp/log.log" : $stdout))

require_relative "db/init"
require_relative "initializers/all"

require "telegram/bot"

$token = ENV["TELEGRAM_TOKEN"].freeze
$admin_chat_id = ENV["ADMIN_CHAT_ID"].to_i.freeze
$mutex = Mutex.new
def $mutex.sync
  $mutex.synchronize { yield }
end

Routes.instance.build!

return unless $PROGRAM_NAME == __FILE__

Telegram::Bot::Client.run($token) do |bot|
  bot.listen do |message|
    if message.respond_to?(:chat) && message.chat.type != "private" && message.chat.id != $admin_chat_id
      LOGGER.error "Someone added the bot to his group chat and it was not admin chat"
    else
      Thread.new do
        Routes.instance.dispatch_controller(bot, message)
      rescue StandardError => e
        msg = "Что-то пошло не так.\nЕсли вы потерялись, вернуться можно нажав на /start"
        ApplicationController.new(bot, message).send(:reply, msg, reply_markup: nil)
        LOGGER.error "Unhandled error when processing request: #{e}\n#{e.full_message}"
        raise e
      end
    end
  end
end
