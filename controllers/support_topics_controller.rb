# here by topics we mean actual conversations and messages bot forwards
class SupportTopicsController < ApplicationController
  def call
    repeat_message(chat_id: $admin_chat_id, 
                   message_thread_id: current_support_request.message_thread_id)
  end

  private

  def current_support_request
    @support_request ||= current_user.support_requests_dataset
                                     .where(status: 0)
                                     .first
  end
end