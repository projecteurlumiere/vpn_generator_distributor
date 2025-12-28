require_relative "../test_helper"

class KeyTest < Minitest::Test
  def test_issuing_reserved_key
    user_1 = create_user
    user_2 = create_user(tg_id: 2)

    kd = create_keydesk
    key = kd.add_key(user_id: user_2.id,
                     keydesk_username: "Alice",
                     reserved_until: Time.now - 1)

    Dir.mkdir "./tmp/vpn_configs/per_key/#{key.id}"

    assert_equal Key.assign_reserved_key(user_2).id, key.id
  end

  def test_not_issuing_reserved_key
    user_1 = create_user
    user_2 = create_user(tg_id: 2)

    kd = create_keydesk
    key = kd.add_key(user_id: user_2.id,
                     keydesk_username: "Alice",
                     reserved_until: Time.now + 3600)

    Dir.mkdir "./tmp/vpn_configs/per_key/#{key.id}"

    assert_nil Key.assign_reserved_key(user_2)
  end
end
