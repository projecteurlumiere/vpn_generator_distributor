class User < Sequel::Model(:users)
  one_to_many :keys

  MAX_KEYS = 5

  def state_array
    arr = state&.split("|") || []
    arr.map! do |s|
      case s
      in "true"
        true
      in "false"
        false
      else
        s
      end
    end
    
    arr
  end

  def too_many_keys?
    keys.count >= MAX_KEYS
  end

  def awaiting_config?
    pending_config_until && pending_config_until > Time.now
  end

  def config_reserved?
    keys.any? { |key| key.reserved_until && key.reserved_until > Time.now }
  end
end
