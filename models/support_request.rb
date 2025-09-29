class SupportRequest < Sequel::Model(:support_requests)
  plugin :enum
  enum :status, unread: 0, open: 1, closed: 2

  STATUS_RU = {
    unread: "📩 Не прочитан",
    open:   "⏳ В работе",
    closed: "✅ Закрыт"
  }.freeze

  def status_ru
    STATUS_RU[status]
  end
end
