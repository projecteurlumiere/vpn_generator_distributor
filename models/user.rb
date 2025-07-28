class User < Sequel::Model(:users)
  one_to_many :keys

  def too_many_keys?
    keys.count >= 5
  end
end
