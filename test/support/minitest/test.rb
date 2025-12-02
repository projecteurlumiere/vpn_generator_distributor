class Minitest::Test
  def teardown
    super

    User.dataset.delete
    SupportRequest.dataset.delete
    Keydesk.dataset.delete
    Key.dataset.delete
  end
end
