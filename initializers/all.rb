require_relative "loader"
require_relative "launch_keydesk_proxies" if ENV["ENV"] != "test"
require_relative "telegram_bot/types_message_patch"
require_relative "telegram_bot/api_patch" if ENV["ENV"] != "test"
