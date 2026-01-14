# frozen_string_literal: true

return if ENV["ENV"] == "test"

at_exit do
  if $PROGRAM_NAME != "bin/console"
    Keydesk.stop_proxies
  end
end

Async do
  Keydesk.start_proxies
end
