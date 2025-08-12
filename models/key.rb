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
    update(pending_destroy_until: Time.now + 120)
    keydesk.delete_user(username: keydesk_username)
    super
  ensure
    update(pending_destroy_until: nil) if exists?
  end

  def awaiting_destroy?
    pending_destroy_until && pending_destroy_until > Time.now
  end

  def self.issue(to:)
    return :keydesk_full unless keydesk = Keydesk.where { n_keys < Keydesk::MAX_USERS }.first
    
    user = to
    user.update(pending_config_until: Time.now + 120)

    keydesk.create_config(user:) # returns key with config
  rescue StandardError => e
    LOGGER.warn "Error #{e} when requesting onfig from #{keydesk.name}"
    return :keydesk_error
  ensure
    user.update(pending_config_until: nil)  
  end
end
