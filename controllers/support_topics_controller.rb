# here by topics we mean actual conversations and messages bot forwards
class SupportTopicsController < ApplicationController
  def call
    if request
      request.update(updated_at: Time.now)
      repeat_message(chat_id: Bot::ADMIN_CHAT_ID,
                     message_thread_id: request.message_thread_id)
    else
      msg = <<~TXT
        Похоже, что ваше обращение в поддержку потерялось.
        Вы можете написать в поддержку с новым обращением или вернуться в меню.
      TXT
      reply_with_buttons(msg, [["Написать в поддержку"], ["Вернуться в меню"]])
    end
  end

  private

  def request
    @request ||= current_user.support_requests_dataset
                             .where(status: [0, 1])
                             .first
  end
end
