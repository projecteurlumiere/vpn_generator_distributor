require "dotenv/load" if ENV["ENV"] != "production"

require "logger"
LOGGER = Logger.new((ENV["ENV"] == "production" ? "tmp/log.log" : $stdout))

require "telegram/bot"
require_relative "db/init"
require_relative "initializers/all"


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
      LOGGER.warn "Someone used the bot in a group chat that is not the admin chat"
    else
      Thread.new do
        Routes.instance.dispatch_controller(bot, message)
      rescue StandardError => e
        controller = ApplicationController.new(bot, message)

        msg = case controller.chat_id
              in ^$admin_chat_id
                <<~TXT
                  ⚠️ Что-то пошло не так: #{e.class}
                TXT
              else
                "Что-то пошло не так.\nЕсли вы потерялись, вернуться можно нажав на /start"
              end

        controller.send(:reply, msg, reply_markup: nil)
        LOGGER.error "Unhandled error when processing request: #{e.class}\n#{e.full_message}\n#{e.backtrace}"
      end
    end
  end
end
