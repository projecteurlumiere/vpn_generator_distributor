class User < Sequel::Model(:users)
  one_to_many :keys

  MAX_KEYS = 5

  def too_many_keys?
    keys.count >= MAX_KEYS
  end
end
