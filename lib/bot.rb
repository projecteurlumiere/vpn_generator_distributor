# frozen_string_literal: true

Bundler.require(:default, ENV["ENV"])

require "base64"
require "fileutils"
require "logger"
require "singleton"
require "uri"
require "yaml"

FileUtils.mkdir_p("tmp")
LOGGER = Logger.new(
  ENV["ENV"] == "development" ? $stdout : "tmp/#{ENV["ENV"]}.log",
  2,        # n of files
  1_048_576 # size of a file
)

require "async"
require "async/semaphore"
require "telegram/bot" unless ENV["ENV"] == "test"

# top-level async-related logging goes to a json file:
if ENV["ENV"] == "production"
  serialized = Console::Output::Serialized.new(File.open("./tmp/async_#{ENV["ENV"]}.json", "a"))
  Console.logger = Console::Logger.new(serialized)
end

module Bot
  TOKEN = ENV["TELEGRAM_TOKEN"].freeze
  ADMIN_CHAT_ID = ENV["ADMIN_CHAT_ID"].to_i.freeze
  ADMIN_IDS = ENV["ADMIN_IDS"].split(",").compact.map { it.strip.to_i }.freeze
  ROOT_DIR = File.expand_path("..", __dir__).freeze

  class << self
    def init
      require_relative File.join(ROOT_DIR, "db/init")
      require_relative File.join(ROOT_DIR, "initializers/all")
    end

    def run!
      Async do
        init

        if $PROGRAM_NAME == "bin/console"
          IRB.start
        else
          Telegram::Bot.configure do |config|
            if ENV["ENV"] == "development"
              config.connection_timeout = 5
            end
          end

          allowed_updates = ["message", "callback_query"]
          bot = Telegram::Bot::Client.new(TOKEN, logger: LOGGER, allowed_updates:)

          prepare_graceful_shutdown(bot)

          start_jobs(bot)
          start_listener(bot)
        end
      end
    end

    private

    def start_listener(bot)
      bot.listen do |message|
        Async do
          Routes.instance.dispatch_controller(bot, message)
        end
      end
    rescue => e
      LOGGER.error "Listener encountered error. #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
    ensure
      LOGGER.warn "Listener exited"
    end

    def start_jobs(bot)
      SendAboutSlideJob.run_async(bot)
      RestartUnstableKeydesksJob.run_async
      DailyRecapJob.run_async(bot)
    end

    def prepare_graceful_shutdown(bot)
      Signal.trap("INT") { shutdown(bot) }
      Signal.trap("TERM") { shutdown(bot) }
    end

    def shutdown(bot)
      [
        bot,
        SendAboutSlideJob,
        RestartUnstableKeydesksJob,
        DailyRecapJob,
        Telegram::Bot::Api::GROUP_THROTTLER,
        Telegram::Bot::Api::USER_THROTTLER
      ].each(&:stop)
    end
  end
end
