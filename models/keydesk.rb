require "base64"
require "uri"

class Keydesk < Sequel::Model(:keydesks)
  plugin :enum
  enum :status, offline: 0, unstable: 1, online: 2

  one_to_many :keys

  MAX_USERS = 250
  UNSTABLE_TIMEOUT = 24 * 60 * 60 # 24 hours
  NEW_KEY_TIMEOUT = 24 * 60 * 60 # 2 days
  ABANDONED_KEY_TIMEOUT = 24 * 60 * 60 * 182 # half a year

  def self.start_proxies
    system("scripts/keydesk_proxy_stop.sh")

    Keydesk.dataset.update(status: 0)

    tasks = []

    Keydesk.all.each do |keydesk|
      next unless keydesk.exists?

      tasks << Async do
        conf = keydesk.decoded_ss_link
        id = keydesk.id
        proxy_port = keydesk.proxy_port

        system(
          "scripts/keydesk_proxy_start.sh",
          keydesk.name,
          conf["server"],
          conf["server_port"].to_s,
          conf["password"],
          conf["method"],
          proxy_port.to_s
        )

        sleep 2
        keydesk.update(n_keys: keydesk.users(update_n_keys: false).size, error_count: 0, last_error_at: nil, status: :online)
      end
    end

    tasks.each(&:wait)
  end

  def before_create
    self.name = name.strip
    self.ss_link = ss_link.strip
    super
  end

  def find_usernames_to_destroy
    list = filter_for_usernames_to_destroy(users)

    list = list.flat_map do
      [
        it["UserName"],
        (Date.parse(it["LastVisitHour"]).strftime("%Y-%m") rescue "-")
      ]
    end

    update(usernames_to_destroy: Sequel.pg_array(list))
  end

  def cleanup_keys
    usernames_to_destroy.map do |username|
      if (key = keys_dataset.where(keydesk_username: username).first)
        key.destroy
      else
        delete_user(username:)
      end

      true
    rescue VpnWorksError
      next false
    end
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

  def users(update_n_keys: true)
    users = vw.users
    update(n_keys: users.size) if update_n_keys
    vw.users
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
    config = vw.create_conf_file

    key = add_key(
      user_id: user.id,
      keydesk_username: config["username"],
      reserved_until: Time.now + 3_600 # 1 hour
    )

    key.config = create_conf_files("./tmp/vpn_configs/per_key/#{key.id}", config)

    key
  end

  def vw
    @vw ||= VpnWorks.new(proxy: proxy_url, id: name)
  end

  def decoded_ss_link
    url = ss_link.sub(/^ss:\/\//, "")
    url_main, _ = url.split("#", 2)

    if url_main.include?("@")
      creds_base64, rest = url_main.split("@", 2)
      method_password = Base64.decode64(creds_base64)
      method, password = method_password.split(":", 2)
      server, port = rest.split(":", 2)
    else
      method_password_server = Base64.decode64(url_main)
      method, rest = method_password_server.split(":", 2)
      password, serverport = rest.split("@", 2)
      server, port = serverport.split(":", 2)
    end

    port = port&.split(/[\/\?#]/,2)[0]

    {
      "method"      => method,
      "password"    => password,
      "server"      => server,
      "server_port" => port.to_i
    }
  end

  def proxy_url
    "socks5://127.0.0.1:#{proxy_port}"
  end

  # ports start at 10000
  def proxy_port
    ((9 + InstanceUtils.number) * 1000) + id
  end

  private

  def create_conf_files(conf_path, data)
    FileUtils.mkdir_p(conf_path)
    data.each do |key, val|
      case key
      in "outline" | "vless"
        outline_key = val["AccessKey"]

        path = File.join(conf_path, "#{key}.txt")
        File.write(path, outline_key)
        data[key] = outline_key
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

  def filter_for_usernames_to_destroy(list)
    list.select do |user|
      res = if user["Status"] == "black"
              created = Time.parse(user["CreatedAt"])
              created_recently = created >= (Time.now - NEW_KEY_TIMEOUT)
              created_recently
            else
              last_visit = Time.parse(user["LastVisitHour"])
              visited_recently = last_visit >= (Time.now - ABANDONED_KEY_TIMEOUT)
              visited_recently
            end
      !res
    end
  end
end
