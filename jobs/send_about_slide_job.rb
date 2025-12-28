# frozen_string_literal: true

# Sending out :about to users who haven't received it after receiving their key
class SendAboutSlideJob < BaseJob
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
                   .where { last_visit_at < Time.now - 2 * 24 * 60 * 60 } # 2 days
                   .select_map(%i[chat_id id])

    chat_ids.each do |(chat_id, id)|
      message = DummyMessage.new(
        DummyChat.new(chat_id),
        DummyFrom.new(0)
      )

      controller = BaseController.new(bot, message)
      controller.send(:reply_slide, :about)
      success << id
    end
  ensure
    User.where(id: success).update(about_received: true, state: nil) if success.any?
  end
end
