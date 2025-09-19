require "base64"
require "uri"

class Keydesk < Sequel::Model(:keydesks)
  one_to_many :keys

  MAX_USERS = 250

  def users
    vw.users
  end

  def user_stats
    vw.user_stats
  end

  def delete_user(id: nil, username: nil)
    id ||= user_id(username)
    vw.delete_user(id)
  end

  def user_id(username)
    vw.user_id(username)
  end

  def create_config(user:)
    key = add_key(
      user_id: user.id,
      reserved_until: Time.now + 3_600 # 1 hour
    )

    begin
      config = vw.create_conf_file("./tmp/vpn_configs/#{key.id}")
    rescue => e
      key.delete
      raise e
    end

    key.update(keydesk_username: config["username"])
    key.config = config
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
    "socks5://127.0.0.1:#{8888 + id}"
  end
end
