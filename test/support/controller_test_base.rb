require_relative "fixtures"
require_relative "fake_bot"

class ControllerTestBase < Minitest::Test
  include Fixtures

  private

  def message_bot(text, from_id: 1, chat_id: 100)
    msg = Telegram::Bot::Types::Message.new(
      text:,
      from: OpenStruct.new(id: from_id, first_name: "test_name", last_name: "test_last_name"),
      chat: OpenStruct.new(id: chat_id)
    )
    Routes.instance.dispatch_controller(bot, msg)
  end

  def bot
    @bot ||= FakeBot.new
  end

  # checks if the given string/pattern was sent by the controller
  # "index" to check the order of the messages
  # "method" to check if any particular controller method was used
  # "not"
  def assert_bot_response(pattern, index: nil, method: nil)
    calls = method ? bot.calls.select { |c| c[:method] == method } : bot.calls
    if index.nil?
      found = calls.any? do |call|
        text = call[:kwargs][:text] || call[:kwargs][:caption] ||
               (call[:args].first[:text] rescue nil) ||
               (call[:args].first[:caption] rescue nil)
        text && text.match?(pattern)
      end
      assert found, "No API call text/caption matched #{pattern.inspect}"
    else
      call = calls[index]
      assert call, "No bot API call at index #{index}#{method ? " for #{method}" : ""}"

      text = call[:kwargs][:text] || call[:kwargs][:caption] ||
             (call[:args].first[:text] rescue nil) ||
             (call[:args].first[:caption] rescue nil)
      assert text, "No text/caption in call at index #{index}"

      assert_match pattern, text
    end
  end

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
      text && text.match?(pattern)
    end
  else
    call = calls[index]
    return false unless call
    text = call[:kwargs][:text] || call[:kwargs][:caption] ||
           (call[:args].first[:text] rescue nil) ||
           (call[:args].first[:caption] rescue nil)
    text && text.match?(pattern)
  end
end

end
