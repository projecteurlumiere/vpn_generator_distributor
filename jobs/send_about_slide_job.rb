class SendAboutSlideJob
  PERFORM_AT = 16 # UTC hour

  # for accessing application controller methods:
  DummyMessage = Struct.new(:chat, :from) do
    def reply_to_message; nil; end
  end
  DummyChat = Struct.new(:id)
  DummyFrom = Struct.new(:id)

  def self.run!(bot)
    Async do
      while true
        if ENV["ENV"] == "production"
          sleep 3600
          next unless Time.now.utc.hour == PERFORM_AT
        else
          sleep 5
        end

        chat_ids = User.where(about_received: false)
                       .where { last_visit_at < Time.now - 2 * 24 * 60 * 60 } # 2 days
                       .select_map(%i[chat_id id])
        success = []

        begin
          chat_ids.each do |(chat_id, id)|
            message = DummyMessage.new(
              DummyChat.new(chat_id),
              DummyFrom.new(0)
            )

            controller = ApplicationController.new(bot, message)
            controller.send(:reply_slide, :about)
            success << id
          end
        ensure
          User.where(id: success).update(about_received: true) if success.any?
        end
      end
    end
  end
end
