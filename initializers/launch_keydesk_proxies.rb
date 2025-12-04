return if ENV["ENV"] == "test"

at_exit do
  system("scripts/keydesk_proxy_stop.sh")
end

Async do
  Keydesk.start_proxies
end
