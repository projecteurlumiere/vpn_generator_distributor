# frozen_string_literal: true

require_relative "loader"
require_relative "seed_data"
require_relative "launch_keydesk_proxies" if ENV["ENV"] != "test"
require_relative "telegram_bot/types_message_patch"
require_relative "telegram_bot/types_callback_query_patch"
require_relative "telegram_bot/api_patch" if ENV["ENV"] != "test"
require_relative "telegram_bot/bot_client_patch"
