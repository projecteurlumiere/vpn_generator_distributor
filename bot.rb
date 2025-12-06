Bundler.require(:default, ENV["ENV"])

require "base64"
require "fileutils"
require "logger"
require "singleton"
require "uri"
require "yaml"

LOGGER = Logger.new(
  ENV["ENV"] == "development" ? $stdout : "tmp/#{ENV["ENV"]}.log",
  10,   # keep 10 rotated log files
  1_048_576 # max log file size in bytes (example: 1 MB)
)

require "async"
require "telegram/bot" unless ENV["ENV"] == "test"

module Bot
  TOKEN = ENV["TELEGRAM_TOKEN"].freeze
  ADMIN_CHAT_ID = ENV["ADMIN_CHAT_ID"].to_i.freeze
  ADMIN_IDS = ENV["ADMIN_IDS"].split(",").compact.map { it.strip.to_i }.freeze
  MUTEX = Mutex.new

  def MUTEX.sync
    Bot::MUTEX.synchronize { yield }
  end

  class << self
    def init
      require_relative "db/init"
      require_relative "initializers/all"
    end

    def run!
      Async do
        init

        if $PROGRAM_NAME == "bin/console" # bin/console shouldn't start the listenter
          IRB.start
        else
          start_listener
        end
      end
    end

    private

    def start_listener
      Telegram::Bot::Client.run(Bot::TOKEN) do |bot|
        bot.listen do |message|
          if message.respond_to?(:chat) && message.chat.type != "private" && message.chat.id != Bot::ADMIN_CHAT_ID
            LOGGER.warn "Someone used the bot in a group chat that is not the admin chat: #{message.chat.id}"

            if Bot::ADMIN_CHAT_ID.to_i == 0
              controller = ApplicationController.new(bot, message)
              controller.send(:reply, "No admin chat provided.\nchat id: `#{controller.chat_id}`", parse_mode: "Markdown")
            end
          else
            Async do
              Routes.instance.dispatch_controller(bot, message)
            rescue StandardError => e
              controller = ApplicationController.new(bot, message)
              msg = case controller.chat_id
                    in ^(Bot::ADMIN_CHAT_ID)
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
    end
  end
end
