class SupportRequest < Sequel::Model(:support_requests)
  many_to_one :user

  plugin :enum
  enum :status, open: 0, closed: 1

  STATUS_RU = {
      open:   "⏳ В работе",
    closed:   "✅ Закрыт"
  }.freeze

  def status_ru
    STATUS_RU[status]
  end

  def before_create
    if user.support_requests_dataset.where(status: :open).count > 0
      raise Sequel::HookFailed, "User #{user.id} still has an open support request!"
    end

    super
  end
end
