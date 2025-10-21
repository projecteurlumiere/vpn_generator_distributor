class SupportRequest < Sequel::Model(:support_requests)
  many_to_one :user

  plugin :enum
  enum :status, unread: 0, open: 1, closed: 2

  STATUS_RU = {
    unread:   "Не прочитан",
      open:   "⏳ В работе",
    closed:   "✅ Закрыт"
  }.freeze

  def status_ru
    STATUS_RU[status]
  end

  def before_create
    if user.support_requests_dataset.where(status: [0, 1]).count > 0
      raise Sequel::HookFailed, "User #{user.id} still has an open support request!"
    end

    super
  end

  def set_open!(bot)
    if unread?
      begin
        bot.api.call("editForumTopic", {
          chat_id: Bot::ADMIN_CHAT_ID,
          name: "Обращение №#{id}",
          message_thread_id:,
          icon_custom_emoji_id: 5238156910363950406
        })
      rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.data["description"]
        in /TOPIC_NOT_MODIFIED/
          LOGGER.warn "Topic #{id} was not modified by #{__method__} in #{self.class}"
        else
          raise e
        end
      end
    end

    DB.transaction do
      user.update(state: ["SupportTopicsController"].join("|"))
      update(status: 1, updated_at: Time.now)
    end
  end

  def set_closed!(bot)
    closed!
    save

    res = bot.api.call("editForumTopic", {
      chat_id: Bot::ADMIN_CHAT_ID,
      name: "Обращение №#{id}",
      message_thread_id:,
      icon_custom_emoji_id: 5237699328843200968
    })
  rescue Telegram::Bot::Exceptions::ResponseError => e
    case e.data["description"]
    in /TOPIC_NOT_MODIFIED/
      LOGGER.warn "Topic #{id} was not modified by #{__method__} in #{self.class}"
    in /message thread not found/
      LOGGER.warn "Topic is missing for request №#{id}."
    else
      raise e
    end
  end
end
