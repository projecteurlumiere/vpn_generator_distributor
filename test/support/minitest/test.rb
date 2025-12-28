class Minitest::Test
  include Fixtures

  def teardown
    super

    SupportRequest.dataset.delete

    Key.dataset.delete
    Keydesk.dataset.delete

    User.dataset.delete
  end
end
