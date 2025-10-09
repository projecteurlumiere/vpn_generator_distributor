class Key < Sequel::Model(:keys)
  many_to_one :user, key: :user_id
  many_to_one :keydesk, key: :keydesk_id

  attr_accessor :config

  def destroy
    update(pending_destroy_until: Time.now + 120)

    attempts = 0
    begin
      keydesk.delete_user(username: keydesk_username)
    rescue StandardError => e
      attempts += 1
      LOGGER.warn "Error #{e.class}: #{e.message} when destroying key=username=#{keydesk_username.inspect}, keydesk=#{keydesk&.name.inspect}, attempt=#{attempts}, backtrace=#{e.backtrace.join("\n")}"
      retry if attempts < 3
    end

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
      max_attempts = 5
      attempt = 0

      begin
        keydesks = Keydesk.where { n_keys < max_keys }
                          .exclude(status: 0) # offline
                          .first(max_attempts)
        return :keydesks_full if keydesks.none?

        current_keydesk = keydesks[attempt]

        user.update(pending_config_until: Time.now + 120)
        key = current_keydesk.create_config(user:)

        DB.transaction do
          current_keydesk.update(n_keys: Sequel[:n_keys] + 1)
          current_keydesk.update_status!
        end

        return key
      rescue StandardError => e
        current_keydesk.record_error!
      
        attempt += 1

        if attempt < keydesks.size
          sleep 0.5
          retry
        end

        LOGGER.warn "Error #{e.class}: #{e.message} when requesting config from keydesk=#{current_keydesk&.name.inspect}, user_id=#{to&.id}, backtrace=#{e.backtrace.join("\n")}"
        return :keydesks_error
      ensure
        user.update(pending_config_until: nil)
      end
    end
  end
end
