class Telegram::Bot::Api
  GROUP_THROTTLER = RateLimiter.new(4)
  USER_THROTTLER = RateLimiter.new(1.0 / 30)

  def call(endpoint, raw_params = {})
    params = build_params(raw_params)
    path = build_path(endpoint)

    response = nil
    with_throttler(*throttler_args(raw_params)) do
      response = connection.post(path, params)
    end

    raise Telegram::Bot::Exceptions::ResponseError.new(response: response) unless response.status == 200

    JSON.parse(response.body)
  end

  private

  def throttler_args(raw_params)
    case raw_params
    in { chat_id: ^$admin_chat_id, message_thread_id: message_thread_id }
      [GROUP_THROTTLER, [$admin_chat_id, message_thread_id].join("_")]
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
