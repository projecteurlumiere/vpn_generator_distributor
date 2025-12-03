require_relative "../test_helper"

class StartControllerTest < ControllerTestBase
  def test_true
    assert_equal(true, true)
  end

  def test_start
    message_bot("/start")
    assert_bot_response(/правила/i)
  end

  def test_rules_read_prompt
    message_bot("/start")
    assert_bot_response(/правила/i)
    message_bot("Ознакомиться с правилами")
    assert_bot_response(/Сначала/i, index: 1)
    message_bot("Правила подтверждаю")
    message_bot("/start")
    refute_bot_response(/правила/i, index: -1)
  end

  def test_start_when_rules_read
    create_user
    message_bot("/start")
    refute_bot_response(/правила/i)
  end

  def test_routing_error
    assert_raises(Routes::ControllerNotFoundError) { message_bot("/srart") }
  end
end
