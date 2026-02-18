# frozen_string_literal: true

module DummyController
  Message = Struct.new(:chat, :from) do
    def reply_to_message; nil; end
  end
  Chat = Struct.new(:id)
  From = Struct.new(:id)

  def generate_dummy_controller(bot)
    message = DummyController::Message.new(
      DummyController::Chat.new(0),
      DummyController::From.new(0)
    )

    controller = ApplicationController.new(bot, message)
  end
end
