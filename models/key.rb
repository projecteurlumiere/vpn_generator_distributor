# frozen_string_literal: true

class Key < Sequel::Model(:keys)
  many_to_one :user, key: :user_id
  many_to_one :keydesk, key: :keydesk_id

  VALID_CONFIGS = %w(amnezia outline vless wireguard).freeze
  attr_accessor :config

  class << self
    def issue(to:, skip_limit: false)
      user = to
      return :user_awaits_config unless user.acquire_config_lock?

      begin
        assign_reserved_key(user) || browse_keydesks_for_keys(user, skip_limit)
      ensure
        user.release_config_lock!
      end
    end

    def assign_reserved_key(user)
      DB.transaction do
        key = Key.where { reserved_until <= Time.now }
                 .for_update
                 .first

        if key && Dir.exist?("./tmp/vpn_configs/per_key/#{key.id}")
          key.update(user_id: user.id, reserved_until: Time.now + 3_600)
        end
      end
    end

    def browse_keydesks_for_keys(user, skip_limit)
      if keydesks_offline?
        LOGGER.warn "Failed to issue key: keydesks are offline" and return :keydesks_offline
      end

      keydesks = find_available_keydesks(skip_limit)
      if keydesks.none?
        LOGGER.warn "Failed to issue key: keydesks are full" and return :keydesks_full
      end

      user.update(pending_config_until: Time.now + 600)

      max_attempts = keydesks.size
      attempt = 0

      begin
        current_keydesk = keydesks[attempt]
        key = current_keydesk.create_config(user:)
        return key
      rescue StandardError => e
        attempt += 1
        retry if attempt < max_attempts

        LOGGER.error "Could not issue key to a user `#{user.id}`. #{e.class}: #{e.message}\nbacktrace=#{e.backtrace.join("\n")}"
        return :keydesks_error
      end
    ensure
      user.update(pending_config_until: nil)
    end

    def find_available_keydesks(skip_limit)
      # online or unstable with less than 5 errors:
      sql = Keydesk.where { (status =~ 2) | ((status =~ 1) & (error_count < 5)) }
      sql = if skip_limit
              sql.where { n_keys < Keydesk::MAX_USERS }
                 .where { max_keys > 0} # if set to 0, we ignore it even for admins
            else
              sql.where { n_keys < max_keys }
            end
      sql.order(:n_keys).all
    end

    def keydesks_offline?
      Keydesk.where { (status =~ 2) | ((status =~ 1) & (error_count < 5)) }.first.nil?
    end
  end

  def destroy
    return :pending_destroy unless acquire_destroy_lock?

    begin
      keydesk.delete_user(username: keydesk_username)
    rescue
      return false
    ensure
      if exists?
        release_destroy_lock!
      else
        dir = "./tmp/vpn_configs/per_key/#{id}"
        FileUtils.rm_rf(dir) if Dir.exist?(dir)
      end
    end

    super
  end

  def acquire_destroy_lock?
    Key.where(id:)
       .where { (pending_destroy_until < Time.now) | (pending_destroy_until =~ nil) }
       .update(pending_destroy_until: Time.now + 600) == 1
  end

  def release_destroy_lock!
    update(pending_destroy_until: nil)
  end
end
