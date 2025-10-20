class Telegram::Bot::Types::Message
  # Topic updates happen to have nil as text
  # This leads to confusing TypeError when error handling code calls `to_s` on this object
  def to_s
    text.to_s
  end
end
