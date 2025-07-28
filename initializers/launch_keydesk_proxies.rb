at_exit do
  system("scripts/keydesk_proxy_stop.sh")
end

system("scripts/keydesk_proxy_stop.sh")


threads = []

Keydesk.all.each do |keydesk|
  threads << Thread.new do
    conf = keydesk.decoded_ss_link
    id = keydesk.id
    name = keydesk.name
    proxy_port = 8888 + id

    system(
      "scripts/keydesk_proxy_start.sh",
      name.to_s,
      conf["server"],
      conf["server_port"].to_s,
      conf["password"],
      conf["method"],
      proxy_port.to_s
    )

    sleep 2
    keydesk.update(n_keys: keydesk.users.size)
  end
end

threads.each(&:join)
