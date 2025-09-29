class Key < Sequel::Model(:keys)
  many_to_one :user, key: :user_id
  many_to_one :keydesk, key: :keydesk_id

  attr_accessor :config

  def destroy
    update(pending_destroy_until: Time.now + 120)
    keydesk.delete_user(username: keydesk_username)
    super
  ensure
    if exists?
      update(pending_destroy_until: nil) 
    else
      per_key_dir  = "./tmp/vpn_configs/per_key/#{id}"
      per_user_dir = "./tmp/vpn_configs/per_user/#{user_id}"
  
      FileUtils.rm_rf(per_key_dir)  if Dir.exist?(per_key_dir)
      FileUtils.rm_rf(per_user_dir) if Dir.exist?(per_user_dir)
    end
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
        keydesk = Keydesk.where { n_keys < max_keys }.where(online: true).first
        return :keydesk_full if keydesk.nil?
  
        user.update(pending_config_until: Time.now + 120)
        key = keydesk.create_config(user:) # returns key with config
        keydesk.update(n_keys: Sequel[:n_keys] + 1)
        key
      rescue StandardError => e
        LOGGER.warn "Error #{e.class}: #{e.message} when requesting config from keydesk=#{keydesk&.name.inspect}, user_id=#{to&.id}, backtrace=#{e.backtrace.join("\n")}"
        return :keydesk_error
      ensure
        user.update(pending_config_until: nil)
      end
    end
  end
end
