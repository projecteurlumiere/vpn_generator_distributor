# frozen_string_literal: true

# Edit messages enqueued to the db
class EditMessagesJob < ApplicationJob
  include DummyController

  PERFORM_EVERY = ENV["ENV"] == "development" ? 10 : 120 # 1 hour

  def perform_now(bot)
    success = []

    Edit.where { perform_at <= Time.now }
        .all
        .each do |edit|
      controller = generate_dummy_controller(bot)

      controller.send(:edit_message, **edit.payload, chat_id: edit.chat_id, message_id: edit.message_id)
      success << edit.id
    rescue => e
      success << edit.id if e.message.match?(/bot was blocked|exactly the same|message to edit not found/)
      LOGGER.warn "Failed to edit the message for chat_id `#{edit.chat_id}`: #{e.class}, #{e.message}"
    end
  ensure
    if success.any?
      Edit.where(id: success).delete
      LOGGER.info "The edit job slide has been succefully done to `#{success.size}` message(s)"
    end
  end
end
