require_relative "../test_helper"

class InstructionsControllerTest < ControllerTestBase
  def test_menu
    message_bot("Подключить VPN")
    assert_bot_response(/Выберите ваше устройство/i)

    flush_replies

    message_bot("К выбору устройства")
    assert_bot_response(/Выберите ваше устройство/i)
  end

  def test_instruction_without_key_issue
    message_bot("Подключить VPN")
    assert_bot_buttons("Android", "Windows")

    message_bot("Android")
    assert_bot_response(Slides.instance[:rules][:text])

    message_bot("Принимаю правила")
    assert_bot_response(/вам понадобится ключ/)

    message_bot("У меня уже есть ключ")
    assert_bot_response(Instructions.instance["android"][:steps][0][:text])

    Instructions.instance["android"][:steps].size.times do |i|
      message_bot(Instructions.instance["android"][:steps][i][:actions].first)
      break if i + 1 == Instructions.instance["android"][:steps].size

      assert_bot_response(Instructions.instance["android"][:steps][i + 1][:text])
    end

    assert_bot_response(/❤️/, index: -2)
    assert_bot_response(Slides.instance[:about][:text], index: -1)
  end
end
