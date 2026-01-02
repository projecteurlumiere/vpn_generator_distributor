# frozen_string_literal: true

# This patch adds throttlers to respect TG limits.
# See Bot::RateLimiter for numbers

class Telegram::Bot::Api
  GROUP_THROTTLER = Bot::RateLimiter.new(4)
  USER_THROTTLER = Bot::RateLimiter.new(1.0 / 30)

  def call(endpoint, raw_params = {})
    params = build_params(raw_params)
    path = build_path(endpoint)

    response = with_throttler(*throttler_args(raw_params)) do
      connection.post(path, params)
    end

    raise Telegram::Bot::Exceptions::ResponseError.new(response: response) unless response.status == 200

    JSON.parse(response.body)
  end

  private

  def throttler_args(raw_params)
    case raw_params
    in { chat_id: ^(Bot::ADMIN_CHAT_ID) }
      [
        GROUP_THROTTLER,
        [
          Bot::ADMIN_CHAT_ID,
          raw_params.fetch(:raw_params, 0) # editing messages dose not have message_thread_id
        ].join("_")
      ]
    in { chat_id: chat_id }
      [USER_THROTTLER, chat_id]
    else
      [nil, nil]
    end
  end

  def with_throttler(throttler, id, &)
    throttler ? throttler.execute(id, &) : yield
  end
end
