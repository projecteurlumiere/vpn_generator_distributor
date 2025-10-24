require "net/http"
require "socksify/http"
require "json"
require "uri"

class VpnWorks
  class VpnWorksError < StandardError; end

  BASE_URL = "https://vpn.works".freeze
  BASE_HEADERS = {
    "Accept"     => "application/json, text/plain, */*",
    "User-Agent" => "ruby/#{RUBY_VERSION}"
  }.freeze

  @@tokens = {}

  def initialize(proxy:, id:)
    @proxy = proxy
    @id = id
    @headers = BASE_HEADERS.dup
  end

  def users
    resp = request("user")
    JSON.parse(resp.body)
  end

  def users_stats
    resp = request("users/stats")
    JSON.parse(resp.body)
  end

  def delete_user(user_id)
    request("user/#{user_id}", type: :delete)
  end

  def user_id(name)
    users.find { |user| user["UserName"] == name }&.fetch("UserID")
  end

  def create_conf_file
    h = get_conf_file
    {
      "username"  => h["UserName"],
      "amnezia"   => h["AmnzOvcConfig"],
      "wireguard" => h["WireguardConfig"],
      "outline"   => h["OutlineConfig"],
      "vless"     => h["Proto0Config"]
    }
  end

  private

  def get_conf_file
    resp = request("user", headers:, type: :post)
    JSON.parse(resp.body)
  end

  def headers
    @headers["Authorization"] = token
    @headers
  end

  def token
    @@tokens[@id] ||= refresh_token
  end

  def refresh_token
    resp = request("token", type: :post, headers: BASE_HEADERS)
    resp = JSON.parse(resp.body)
    @@tokens[@id] = resp["Token"]
    LOGGER.info("Successfully updated authentication token for Keydesk #{@id}")
    token
  end

  def request(endpoint, type: :get, headers: self.headers)
    uri = URI("#{BASE_URL}/#{endpoint}")
    http = make_http(uri)

    request_class = Net::HTTP.const_get(type.to_s.capitalize)
    req = request_class.new(uri, headers)
    resp = http.request(req)

    return resp if resp.is_a?(Net::HTTPSuccess)

    raise VpnWorksError
  rescue StandardError => e
    attempt ||= 1
    attempt += 1

    if attempt <= 3
      case e
      in VpnWorksError
        LOGGER.error "Error in the keydesk #{@id}. Attempts: #{attempt} / 3"
        refresh_token if resp.code == 401
        retry
      else
        LOGGER.error "Error #{e.class} when *reaching* keydesk #{@id}. Attempts: #{attempt} / 3"
        retry
      end
    else
      msg = <<~MSG.strip
        Unable to proceed with the request for keydesk #{@id} after #{attempt} attempts.
        Original error: #{e.class}: #{e.message}
      MSG

      raise VpnWorksError, msg
    end
  end

  def make_http(uri)
    proxy_uri = URI(@proxy)
    http = Net::HTTP.SOCKSProxy(proxy_uri.host, proxy_uri.port).new(uri.host, uri.port)

    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http
  end
end
