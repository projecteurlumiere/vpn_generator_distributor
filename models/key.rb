class Key < Sequel::Model(:keys)
  many_to_one :user, key: :user_id
  many_to_one :keydesk, key: :keydesk_id

  SUITS = ["🃏", "♠️", "♥️", "♣️", "♦️"]

  def before_create
    super
    taken = user.keys_dataset.exclude(id: self.id).select_map(:personal_note)
    avail = SUITS - taken
    self.personal_note = avail.sample if avail.any?
  end
end
