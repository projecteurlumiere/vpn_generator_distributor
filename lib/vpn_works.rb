require "net/http"
require "socksify/http"
require "json"
require "uri"

# handles vpn.works API
class VpnWorks
  class VpnWorksError < StandardError; end

  BASE_URL = "https://vpn.works".freeze

  def initialize(proxy:)
    @base_headers = { "Accept" => "application/json, text/plain, */*", "User-Agent" => "python-httpx/0.27.0" }
    @user_headers = @base_headers.dup
    @config_headers = { "Accept" => "application/json" }
    @proxy = proxy
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
    request("user/#{user_id}", req_type: :delete)
  end

  def user_id(name)
    users_dict = users.to_h { |user| [user["UserName"], user] }
    (users_dict[name.to_s] || {})["UserID"]
  end

  def create_conf_file
    data = get_conf_file
    {
      "username" => data["UserName"],
      "amnezia" => data["AmnzOvcConfig"],
      "wireguard" => data["WireguardConfig"],
      "outline" => data["OutlineConfig"],
      "vless" => data["Proto0Config"]
    }
  end

  private

  def token
    @token ||= get_token
  end

  def get_conf_file
    resp = request("user", headers: @config_headers, req_type: :post)
    JSON.parse(resp.body)
  end

  def get_token
    uri = URI("#{BASE_URL}/token")

    http = make_http(uri)

    req = Net::HTTP::Post.new(uri, @base_headers)
    resp = http.request(req)

    raise VpnWorksError, "Error from server: #{resp.message}" unless resp.is_a?(Net::HTTPSuccess)

    data = JSON.parse(resp.body)

    @token = data["Token"]
    @user_headers["Authorization"] = "Bearer #{@token}"
    @config_headers["Authorization"] = "Bearer #{@token}"
    LOGGER.info("Successfully obtained authentication token")
  rescue StandardError => e
    LOGGER.error("Failed to get token: #{e}")
    raise
  end

  def request(endpoint, req_type: :get, headers: nil, attempt: 0)
    headers ||= @user_headers

    uri = URI("#{BASE_URL}/#{endpoint}")

    http = make_http(uri)

    request_class = {
      get: Net::HTTP::Get,
      post: Net::HTTP::Post,
      delete: Net::HTTP::Delete
    }[req_type]

    req = request_class.new(uri, headers)

    resp = http.request(req)
    if resp.code.to_i == 401 && attempt < 3
      get_token
      headers["Authorization"] = "Bearer #{@token}"
      return request(endpoint, req_type: req_type, headers: headers, attempt: attempt + 1)
    end

    raise VpnWorksError, resp.message unless resp.is_a?(Net::HTTPSuccess)

    resp
  end

  def make_http(uri)
    if @proxy
      proxy_uri = URI(@proxy)
      http = Net::HTTP.SOCKSProxy(proxy_uri.host, proxy_uri.port).new(uri.host, uri.port)
    else
      http = Net::HTTP.new(uri.host, uri.port)
    end

    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http
  end
end
