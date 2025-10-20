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
end
