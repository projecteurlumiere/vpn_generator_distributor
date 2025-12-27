class Keydesk < Sequel::Model(:keydesks)
  include Keydesk::ProxyManagement
  include Keydesk::KeysCleanUp

  plugin :enum
  enum :status, offline: 0, unstable: 1, online: 2

  one_to_many :keys

  MAX_USERS = 250
  UNSTABLE_TIMEOUT = 24 * 60 * 60 # 24 hours

  def before_create
    self.name = name.strip
    self.ss_link = ss_link.strip
    super
  end

  def users(update_n_keys: true)
    users = vw.users
    update(n_keys: users.size) if update_n_keys
    vw.users
  end

  def vw
    @vw ||= VpnWorks.new(proxy: proxy_url, id: name)
  end

  def users_stats
    vw.users_stats
  end

  def delete_user(id: nil, username: nil)
    id ||= user_id(username)
    vw.delete_user(id)
    self.update(n_keys: Sequel[:n_keys] - 1)
  end

  def user_id(username)
    vw.user_id(username)
  end

  def create_config(user:)
    update(n_keys: Sequel[:n_keys] + 1)
    config = vw.create_conf_file

    key = add_key(
      user_id: user.id,
      keydesk_username: config["username"],
      reserved_until: Time.now + 3_600 # 1 hour
    )

    key.config = create_conf_files("./tmp/vpn_configs/per_key/#{key.id}", config)

    key
  rescue StandardError => e
    update(n_keys: Sequel[:n_keys] - 1)
    raise
  end

  def record_error!
    now = Time.now
    DB.transaction do
      update(error_count: Sequel[:error_count] + 1, last_error_at: now)
      reload
      update_status!
    end
  end

  def update_status!
    if last_error_at && Time.now - last_error_at > UNSTABLE_TIMEOUT
      update(error_count: 0, status: :online)
    elsif error_count > 0 && Time.now - last_error_at <= UNSTABLE_TIMEOUT
      update(status: :unstable)
    end
  end

  private

  def create_conf_files(conf_path, data)
    FileUtils.mkdir_p(conf_path)

    data.each do |key, val|
      case key
      in "outline" | "vless"
        vpn_key = val["AccessKey"]

        path = File.join(conf_path, "#{key}.txt")
        File.write(path, vpn_key)
        data[key] = vpn_key
      in "amnezia" | "wireguard"
        filename = val["FileName"]
        ext = File.extname(filename)
        file_content = val["FileContent"]

        filename = [key, ext].join
        path = File.join(conf_path, filename)
        File.write(path, file_content)
        data[key] = path
      in "username"
        next
      end
    end

    data
  end
end
