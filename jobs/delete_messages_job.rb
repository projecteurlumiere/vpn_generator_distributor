# frozen_string_literal: true

# Edit messages enqueued to the db
class DeleteMessagesJob < ApplicationJob
  include DummyController

  PERFORM_EVERY = ENV["ENV"] == "development" ? 10 : 120 # 1 hour

  def perform_now(bot)
    success = []

    Delete.where { perform_at <= Time.now }
          .select_map(%i[id chat_id message_id])
          .each do |(id, chat_id, message_id)|
      controller = generate_dummy_controller(bot)

      controller.send(:delete_message, chat_id:, message_id:)
      success << id
    rescue => e
      success << id if e.message.match?(/bot was blocked|message to delete not found/)
      LOGGER.warn "Failed to delete the message to chat_id `#{chat_id}`: #{e.class}, #{e.message}"
    end
  ensure
    if success.any?
      Delete.where(id: success).delete
      LOGGER.info "The delete job slide has been succefully done to `#{success.size}` message(s)"
    end
  end
end
