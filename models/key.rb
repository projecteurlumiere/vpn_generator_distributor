class Key < Sequel::Model(:keys)
  many_to_one :user, key: :user_id
  many_to_one :keydesk, key: :keydesk_id

  attr_accessor :config

  SUITS = ["🃏", "♠️", "♥️", "♣️", "♦️"]

  def before_create
    taken = user.keys_dataset.exclude(id: self.id).select_map(:personal_note)
    avail = SUITS - taken
    self.personal_note = avail.sample if avail.any?
    super
  end

  def destroy
    keydesk.delete_user(username: keydesk_username)
    super
  end

  def self.issue(to:)
    return :keydesk_full unless keydesk = Keydesk.where { n_keys < Keydesk::MAX_USERS }.first
    
    begin
      key = keydesk.create_config(user: to)
    rescue StandardError => e
      LOGGER.warn "Error #{e} when requesting config from #{keydesk.name}"
      return :keydesk_error
    end

    key
  end
end
