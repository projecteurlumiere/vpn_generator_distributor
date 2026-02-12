require_relative "../test_helper"

class KeydeskTest < Minitest::Test
  def test_filter_for_usernames_to_destroy
    user = create_user
    kd = create_keydesk
    Key.create(user_id: user.id, keydesk_username: "4", keydesk_id: kd.id, reserved_until: Time.now + 3600)    # still reserved
    Key.create(user_id: user.id, keydesk_username: "5", keydesk_id: kd.id, reserved_until: Time.now - 500_000) # reservation is gone

    list = [
      { "Status" => "black", "UserName" => "1", "CreatedAt" => Time.now.utc.iso8601 },               # not to remove
      { "Status" => "black", "UserName" => "2", "CreatedAt" => "2024-09-27T16:00:00.000Z" },         # remove
      { "Status" => "black", "UserName" => "3", "CreatedAt" => (Time.now - 3600).utc.iso8601 },      # not to remove
      { "Status" => "black", "UserName" => "4", "CreatedAt" => (Time.now - 1_000_000).utc.iso8601 }, # not to remove because of the key above
      { "Status" => "black", "UserName" => "5", "CreatedAt" => (Time.now - 1_000_000).utc.iso8601 }, # remove because of the key above

      { "Status" => "green", "UserName" => "6", "LastVisitHour" => "2025-09-27T16:00:00.000Z" },    # not to remove
      { "Status" => "gray", "UserName" => "7", "LastVisitHour" => "2025-01-27T16:00:00.000Z" },     # remove
      { "Status" => "gray", "UserName" => "8", "LastVisitHour" => (Time.now - 3600).utc.iso8601 }   # not to remove
    ]

    result = kd.send(:filter_for_usernames_to_destroy, list)

    expected = list.values_at(1, 4, 6)
    assert_equal(result, expected)
  end
end
