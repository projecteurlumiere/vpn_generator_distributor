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
  10,       # n of files
  1_048_576 # size of a file
)

require "async"
require "async/semaphore"
require "telegram/bot" unless ENV["ENV"] == "test"

module Bot
  TOKEN = ENV["TELEGRAM_TOKEN"].freeze
  ADMIN_CHAT_ID = ENV["ADMIN_CHAT_ID"].to_i.freeze
  ADMIN_IDS = ENV["ADMIN_IDS"].split(",").compact.map { it.strip.to_i }.freeze
  ROOT_DIR = File.expand_path("..", __dir__)

  class << self
    def init
      require_relative File.join(ROOT_DIR, "db/init")
      require_relative File.join(ROOT_DIR, "initializers/all")
    end

    def run!
      Async do
        init

        if $PROGRAM_NAME == "bin/console" # bin/console shouldn't start the listenter
          IRB.start
        else
          bot = Telegram::Bot::Client.new(Bot::TOKEN, logger: LOGGER)

          # TODO: further implement graceful shutdown
          # Signal.trap("INT") { bot.stop }

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
    end

    def start_jobs(bot)
      SendAboutSlideJob.run_async(bot)
    end
  end
end
