# frozen_string_literal: true

require "net/http"
require "socksify/http"
require "json"
require "uri"

# Adapted from https://github.com/4erdenko/VPN-Generator-Manager
class VpnWorks
  class Error < StandardError; end

  class ConnectionError < Error; end # usually proxy/server refuses connection

  class ResponseError < Error; end
  class UserLimitExceededError < ResponseError; end    # max users count exceeds limit
  class InvalidTokenError < ResponseError; end         # security token expired
  class UserAlreadyDestroyedError < ResponseError; end # user id not found on server
  class UnknownError < ResponseError; end

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
    @@tokens.dig(@id, Time.now.hour) || refresh_token
  end

  def refresh_token
    resp = request("token", type: :post, headers: BASE_HEADERS)
    resp = JSON.parse(resp.body)
    @@tokens[@id] = { Time.now.hour => resp["Token"] }
    LOGGER.info("Successfully updated authentication token for keydesk `#{@id}`")
    token
  end

  def request(endpoint, type: :get, headers: self.headers)
    caller_method = caller_locations(1)&.first&.base_label # for logs

    uri = URI("#{BASE_URL}/#{endpoint}")
    http = make_http(uri)

    request_class = Net::HTTP.const_get(type.to_s.capitalize)
    req = request_class.new(uri, headers)
    resp = http.request(req)

    if resp.is_a?(Net::HTTPSuccess)
      resp
    else
      handle_unsuccesful_response(resp, caller_method)
    end
  rescue => e
    attempt ||= 0
    attempt += 1

    LOGGER.error <<~TXT
      Connection error from Keydesk `#{@id}`;
      Original error: #{e.class};
      Original message: #{e.message};
      Caller: `#{caller_method}`;
      Attempts: #{attempt}.
    TXT

    case e
    in ResponseError
      raise
    in StandardError if attempt <= 3
      retry
    else
      raise ConnectionError
    end
  end

  def make_http(uri)
    proxy_uri = URI(@proxy)
    http = Net::HTTP.SOCKSProxy(proxy_uri.host, proxy_uri.port).new(uri.host, uri.port)

    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE # since we're securely proxied
    http
  end

  def handle_unsuccesful_response(resp, caller_method)
    case resp.body
    in /method DELETE is not allowed/i if caller_method == "delete_user"
      raise UserAlreadyDestroyedError
    in /invalid token/i
      raise InvalidTokenError
    in "" if resp.code == "500" && caller_method == "get_conf_file"
      raise UserLimitExceededError
    else
      raise UnknownError, "code: #{resp.code}; body: `#{resp.body}`"
    end
  end
end
