class Telegram::Bot::Types::Message
  # MERGED
  #
  # Topic updates happen to have nil as text
  # This leads to confusing TypeError when error handling code calls `to_s` on this object
  def to_s
    text.to_s
  end
end
