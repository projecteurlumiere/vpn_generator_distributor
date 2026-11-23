# frozen_string_literal: true

class Delete < Sequel::Model(:deletes)
  def self.schedule(chat_id:, message_id:, perform_at: nil)
    self.create(chat_id:, message_id:, perform_at:)
  end

  def perform_at=(arg)
    arg ||= Time.now + (ENV["ENV"] == "development" ? 10 : 3600)
    raise ArgumentError unless arg.is_a? Time

    super arg
  end
end
