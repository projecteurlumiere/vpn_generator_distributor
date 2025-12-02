class FakeBot
  attr_reader :calls, :api

  def initialize
    @api = self
    @calls = []
  end

  def method_missing(method, *args, **kwargs, &block)
    @calls << { method: method, args: args, kwargs: kwargs }
    nil
  end
end
