 Key < Sequel::Model(:keys)
  many_to_one :user, key: :user_id
  many_to_one :keydesk, key: :keydesk_id

  VALID_CONFIGS = %w(amnezia outline vless wireguard).freeze
  attr_accessor :config

  def destroy
    return :pending_destroy unless acquire_destroy_lock?

    begin
      keydesk.delete_user(username: keydesk_username)
      keydesk.update_status!
    rescue VpnWorksError => e
      keydesk.record_error!
      raise
    end

    super
  ensure
    if exists?
      release_destroy_lock!
    else
      per_key_dir  = "./tmp/vpn_configs/per_key/#{id}"
      per_user_dir = "./tmp/vpn_configs/per_user/#{user_id}"

      FileUtils.rm_rf(per_key_dir)  if Dir.exist?(per_key_dir)
      FileUtils.rm_rf(per_user_dir) if Dir.exist?(per_user_dir)
    end
  end

  def acquire_destroy_lock?
    Key.where(id:)
       .where { (pending_destroy_until < Time.now) | (pending_destroy_until =~ nil) }
       .update(pending_destroy_until: Time.now + 120) == 1
  end

  def release_destroy_lock!
    update(pending_destroy_until: nil)
  end

  def self.issue(to:, skip_limit: false)
    user = to

    if !user.acquire_config_lock?
      return :user_awaits_config
    elsif key = assign_already_reserved_key
      key
    else
      max_attempts = 5
      attempt = 0

      begin
        user.update(pending_config_until: Time.now + 120)

        limit = skip_limit ? Keydesk::MAX_USERS : max_keys
        keydesks = Keydesk.where { n_keys < limit }
                          .exclude(status: 0) # offline
                          .first(max_attempts)
        return :keydesks_full if keydesks.none?

        current_keydesk = keydesks[attempt]

        key = current_keydesk.create_config(user:)
        current_keydesk.update_status!

        return key
      rescue VpnWorksError => e
        current_keydesk.record_error!

        attempt += 1

        if attempt < keydesks.size
          sleep 0.5
          retry
        end

        LOGGER.warn "Error #{e.class}: #{e.message} when requesting config from keydesk=#{current_keydesk&.name.inspect}, user_id=#{to&.id}, backtrace=#{e.backtrace.join("\n")}"
        return :keydesks_error
      ensure
        user.release_config_lock!
      end
    end
  end

  def self.assign_already_reserved_key
    DB.transaction do
      key = Key.where { reserved_until <= Time.now }
               .for_update
               .first
      key.update(user_id: user.id, reserved_until: Time.now + 3_600) if key
    end
  end
end
