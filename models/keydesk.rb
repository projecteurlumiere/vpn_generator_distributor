require "base64"
require "uri"

class Keydesk < Sequel::Model(:keydesks)
  plugin :enum
  enum :status, offline: 0, unstable: 1, online: 2

  one_to_many :keys

  MAX_USERS = 250
  UNSTABLE_TIMEOUT = 24 * 60 * 60 # 24 hours

  def self.start_proxies
    system("scripts/keydesk_proxy_stop.sh")

    Keydesk.dataset.update(status: 0)

    threads = []

    Keydesk.all.each do |keydesk|
      threads << Thread.new do
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
        keydesk.update(n_keys: keydesk.users.size, error_count: 0, last_error_at: nil, status: :online)
      end
    end

    threads.each(&:join)
  end

  def record_error!
    now = Time.now
    DB.transaction do
      update(error_count: Sequel[:error_count] + 1, last_error_at: now)
      update_status!
    end
  end

  def update_status!
    if last_error_at && Time.now - last_error_at > UNSTABLE_TIMEOUT
      update(error_count: 0, status: :online)
    elsif error_count.to_i > 0 && Time.now - last_error_at <= UNSTABLE_TIMEOUT
      update(status: :unstable)
    end
  end

  def users
    vw.users
  end

  def users_stats
    vw.users_stats
  end

  def delete_user(id: nil, username: nil)
    id ||= user_id(username)
    vw.delete_user(id)
    self.update(n_keys: Sequel[:n_keys] - 1)
  rescue StandardError => e
    LOGGER.warn "Error #{e.class}: #{e.message} deleting user with id=#{id.inspect}, username=#{username.inspect}, backtrace=#{e.backtrace.first(4).join('; ')}"
    raise e
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
    @vw ||= VpnWorks.new(proxy: proxy_url)
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
      "method" => method,
      "password" => password,
      "server" => server,
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
end
