require "minitest/autorun"
require "webmock/minitest"
require "ostruct"

Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

require_relative "../bot"

Bot.init
