# frozen_string_literal: true

# Sending out :about to users who haven't received it after receiving their key
class SendAboutSlideJob < Bot::Job
  PERFORM_AT = 16 # UTC hour

  # for accessing application controller methods:
  DummyMessage = Struct.new(:chat, :from) do
    def reply_to_message; nil; end
  end
  DummyChat = Struct.new(:id)
  DummyFrom = Struct.new(:id)

  def perform_now(bot)
    success = []

    chat_ids = User.where(about_received: false)
                   .where { last_visit_at < Time.now - 172_800 } # 2 days
                   .select_map(%i[chat_id id])

    chat_ids.each do |(chat_id, id)|
      message = DummyMessage.new(
        DummyChat.new(chat_id),
        DummyFrom.new(0)
      )

      controller = ApplicationController.new(bot, message)
      controller.send(:reply_about)
      success << id
    rescue => e
      LOGGER.warn "Failed to send the about slide to chat_id `#{chat_id}`: #{e.class}, #{e.message}"
    end
  ensure
    if success.any?
      User.where(id: success).update(about_received: true, state: nil)
      LOGGER.info "The about slide has been sent to `#{success.size}` user(s)"
    end
  end
end
