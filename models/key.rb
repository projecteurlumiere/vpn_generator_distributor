class Key < Sequel::Model(:keys)
  many_to_one :user, key: :user_id
  many_to_one :keydesk, key: :keydesk_id

  attr_accessor :config

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
    user = to

    if key = Key.where { reserved_until <= Time.now }.first
      key.update(user_id: user.id, reserved_until: Time.now + 3_600)
      key
    else
      begin
        keydesk = Keydesk.where { n_keys < Keydesk::MAX_USERS }.first
        return :keydesk_full if keydesk.nil?
  
        user.update(pending_config_until: Time.now + 120)
        keydesk.create_config(user:) # returns key with config
      rescue StandardError => e
        LOGGER.warn "Error #{e} when requesting config from #{keydesk.name}"
        return :keydesk_error
      ensure
        user.update(pending_config_until: nil)  
      end
    end
  end
end
