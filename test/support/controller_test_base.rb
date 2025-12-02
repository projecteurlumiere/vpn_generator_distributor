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
end
