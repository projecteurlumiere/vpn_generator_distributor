class User < Sequel::Model(:users)
  one_to_many :keys

  MAX_KEYS = 5

  def too_many_keys?
    keys.count >= MAX_KEYS
  end

  def awaiting_config?
    pending_config_until && pending_config_until > Time.now
  end
end
