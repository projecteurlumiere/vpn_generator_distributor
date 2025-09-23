at_exit do
  system("scripts/keydesk_proxy_stop.sh")
end

Keydesk.start_proxies