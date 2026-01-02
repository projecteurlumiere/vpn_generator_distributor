# This patch enabled callback query logging

class Telegram::Bot::Types::CallbackQuery
  def to_s
    data.to_s
  end
end
