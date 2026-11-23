# frozen_string_literal: true

class Edit < Sequel::Model(:edits)
  def self.schedule(chat_id:, message_id:, perform_at: nil, payload:)
    self.create(chat_id:, message_id:, perform_at:, payload:)
  end

  def payload=(arg)
    super JSON.dump(arg)
  end

  def payload
    JSON.parse(super, symbolize_names: true)
  end

  def perform_at=(arg)
    arg ||= Time.now + (ENV["ENV"] == "development" ? 10 : 3600)
    raise ArgumentError unless arg.is_a? Time

    super arg
  end
end
