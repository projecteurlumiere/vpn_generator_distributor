InstanceUtils.record

at_exit do
  system("scripts/keydesk_proxy_stop.sh")
end

Thread.new do
  Keydesk.start_proxies
end
