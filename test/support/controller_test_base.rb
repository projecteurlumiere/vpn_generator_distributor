require_relative "fixtures"
require_relative "fake_bot"

class ControllerTestBase < Minitest::Test
  include Fixtures

  private

  def message_bot(text, from_id: 1, chat_id: 100, chat_type: "private")
    msg = Telegram::Bot::Types::Message.new(
      text:,
      from: OpenStruct.new(id: from_id, first_name: "test_name", last_name: "test_last_name"),
      chat: OpenStruct.new(id: chat_id, type: chat_type),
    )
    Bot::Routes.instance.dispatch_controller(bot, msg)
  end

  def bot
    @bot ||= FakeBot.new
  end

  def flush_replies
    bot.calls.clear
  end

  #
  # AI atrocities below
  #

  def assert_bot_buttons(*buttons, index: nil, method: nil)
    calls = method ? bot.calls.select { |c| c[:method] == method } : bot.calls
    call = index ? calls[index] : calls.last
    assert call, "No bot API call at index #{index || calls.size - 1}#{method ? " for #{method}" : ""}"

    kb = call[:kwargs][:reply_markup] || (call[:args].first[:reply_markup] rescue nil)
    btns = []

    if kb
      rows =
        if kb.respond_to?(:inline_keyboard) && kb.inline_keyboard
          kb.inline_keyboard
        elsif kb.respond_to?(:keyboard) && kb.keyboard
          kb.keyboard
        elsif kb.is_a?(Hash) && kb[:inline_keyboard]
          kb[:inline_keyboard]
        elsif kb.is_a?(Hash) && kb[:keyboard]
          kb[:keyboard]
        else
          []
        end
      btns = rows.flatten
    end

    texts = btns.map { |btn| btn.respond_to?(:text) ? btn.text : btn[:text] }
    assert_includes texts, *buttons
  end

  # checks if the given string/pattern was sent by the controller
  # "index" to check the order of the messages
  # "method" to check if any particular controller method was used
  def assert_bot_response(pattern, index: nil, method: nil)
    found = find_call_match(pattern, index: index, method: method)
    if index
      assert found, "No match for #{pattern.inspect} at index #{index}#{method ? " for #{method}" : ""}"
    else
      assert found, "No API call text/caption matched #{pattern.inspect}"
    end
  end

  def refute_bot_response(pattern, index: nil, method: nil)
    found = find_call_match(pattern, index: index, method: method)
    if index
      refute found, "Unexpected match for #{pattern.inspect} at index #{index}#{method ? " for #{method}" : ""}"
    else
      refute found, "Expected NO API call text/caption to match #{pattern.inspect}, but found one"
    end
  end

  def find_call_match(pattern, index: nil, method: nil)
    calls = method ? bot.calls.select { |c| c[:method] == method } : bot.calls

    if index.nil?
      calls.any? do |call|
        text = call[:kwargs][:text] || call[:kwargs][:caption] ||
               (call[:args].first[:text] rescue nil) ||
               (call[:args].first[:caption] rescue nil)
        case pattern
        in Regexp
          text.match?(pattern)
        in String
          text == pattern
        else
          false
        end
      end
    else
      call = calls[index]
      return false unless call

      text = call[:kwargs][:text] || call[:kwargs][:caption] ||
             (call[:args].first[:text] rescue nil) ||
             (call[:args].first[:caption] rescue nil)
      case pattern
      in Regexp
        text.match?(pattern)
      in String
        text == pattern
      else
        false
      end
    end
  end
end
