require_relative "../test_helper"

class KeydeskTest < Minitest::Test
  def setup
    # @kd = Keydesk.new
  end

  def test_filter_for_usernames_to_destroy
    kd = Keydesk.new

    list = [
      { "Status" => "black", "CreatedAt" => Time.now.utc.iso8601 }, # good 
      { "Status" => "black", "CreatedAt" => "2024-09-27T16:00:00.000Z" }, # bad
      { "Status" => "green", "LastVisitHour" => "2025-09-27T16:00:00.000Z" }, # good
      { "Status" => "gray", "LastVisitHour" => "2025-01-27T16:00:00.000Z" }  # bad
    ]

    result = kd.send(:filter_for_usernames_to_destroy, list)

    expected = [
      { "Status" => "black", "CreatedAt" => "2024-09-27T16:00:00.000Z" },
      { "Status" => "gray", "LastVisitHour" => "2025-01-27T16:00:00.000Z" }
    ]

    assert_equal(result, expected)
  end
end
