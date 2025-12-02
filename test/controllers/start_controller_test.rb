require_relative "../test_helper"

class StartControllerTest < ControllerTestBase
  def test_true
    assert_equal(true, true)
  end

  def test_start
    message_bot("/start")
    assert_bot_response(/Привет/i)
  end
end
