class User < Sequel::Model(:users)
  one_to_many :keys
  one_to_many :support_requests

  MAX_KEYS = 3

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

  def config_reserved?
    keys.any? { |key| key.reserved_until && key.reserved_until > Time.now }
  end

  def acquire_config_lock?
    User.where(id:)
        .where { (pending_config_until < Time.now) | (pending_config_until =~ nil) }
        .update(pending_config_until: Time.now + 120) == 1
  end

  def release_config_lock!
    update(pending_config_until: nil)
  end

  def admin?
    Bot::ADMIN_IDS.any?(tg_id)
  end
end
