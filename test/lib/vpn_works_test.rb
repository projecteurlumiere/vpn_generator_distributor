require_relative "../test_helper"

class VpnWorksTest < Minitest::Test
  def setup
    VpnWorks.class_variable_set(:@@tokens, {})
    @vpn_works = VpnWorks.new(proxy: "socks5://127.0.0.1:10001", id: 1)

    @token = "security_token"
    stub_request(:post, "https://vpn.works/token")
      .to_return(
        status: 200,
        body: { "Token" => "security_token" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def teardown
    WebMock.reset!
  end

  def test_token_refresh
    assert_equal @token, @vpn_works.send(:token)
  end

  def test_users_and_user_id
    users_response = [
      { "UserName" => "alice", "UserID" => 1 },
      { "UserName" => "bob",   "UserID" => 2 }
    ]

    stub_request(:get, "https://vpn.works/user")
      .with(headers)
      .to_return(
        status: 200,
        body: users_response.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    users = @vpn_works.users

    # /user
    assert_equal users_response, users

    # fetching user_id from /user
    assert_equal 1, @vpn_works.user_id("alice")
    assert_equal 2, @vpn_works.user_id("bob")
    assert_nil @vpn_works.user_id("charlie")
  end

  def test_create_conf_file
    conf_response = {
      "UserName"        => "alice",
      "AmnzOvcConfig"   => "amnezia_config",
      "WireguardConfig" => "wg_config",
      "OutlineConfig"   => "outline_config",
      "Proto0Config"    => "vless_config"
    }

    stub_request(:post, "https://vpn.works/user")
      .with(headers)
      .to_return(
        status: 200,
        body: conf_response.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    expected = {
      "username"  => "alice",
      "amnezia"   => "amnezia_config",
      "wireguard" => "wg_config",
      "outline"   => "outline_config",
      "vless"     => "vless_config"
    }

    result = @vpn_works.create_conf_file

    assert_equal expected, result
  end

  # Errors:
  # Too many keys
  # Cannot destroy user
  # Random/Connection error: Errno::ECONNREFUSED
  # Too many keys (error code - 500)

  def test_user_limit_exceeded_error
    stub_request(:post, "https://vpn.works/user")
      .with(headers)
      .to_return(status: 500, body: "")

    assert_raises VpnWorks::UserLimitExceededError do
      @vpn_works.create_conf_file
    end
  end

  def test_invalid_token_error
    stub_request(:get, "https://vpn.works/user")
      .with(headers)
      .to_return(status: 401, body: "invalid token")

    assert_raises VpnWorks::InvalidTokenError do
      @vpn_works.users
    end
  end

  def test_user_already_destroyed_error
    stub_request(:delete, "https://vpn.works/user/123")
      .with(headers)
      .to_return(status: 405, body: "method DELETE is not allowed")

    assert_raises VpnWorks::UserAlreadyDestroyedError do
      @vpn_works.delete_user(123)
    end
  end

  def test_unknown_error
    stub_request(:get, "https://vpn.works/user")
      .with(headers)
      .to_return(status: 418, body: "I'm a teapot")

    assert_raises VpnWorks::UnknownError do
      @vpn_works.users
    end
  end

  private

  def headers
    { headers: { "Authorization" => @token } }
  end
end
