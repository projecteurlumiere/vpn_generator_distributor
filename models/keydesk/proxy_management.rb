# frozen_string_literal: true

require "base64"

module Keydesk::ProxyManagement
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def start_proxies
      Keydesk.dataset.update(status: 0)

      tasks = []

      Keydesk.all.each do |keydesk|
        next unless keydesk.exists?

        tasks << Async do
          handle_proxy_running and next if proxy_running?(keydesk.name, keydesk.proxy_port)

          keydesk.launch_proxy
          sleep 2
          keydesk.update(n_keys: keydesk.users(update_n_keys: false).size,
                         error_count: 0,
                         last_error_at: nil,
                         status: :online)
        end
      end

      tasks.each(&:wait)
    end

    def proxy_running?(name, port)
      pidfile = "./tmp/proxies/ss-local-#{name}.pid"
      return false unless File.exist?(pidfile)

      pid = File.read(pidfile).strip.to_i
      cmdline = File.read("/proc/#{pid}/cmdline").tr("\0", " ")
      cmdline.include?("ss-local") && cmdline.include?("-l #{port}")
    rescue Errno::ENOENT, Errno::ESRCH
      false
    end

    def handle_proxy_running
      msg = "The proxy for `#{keydesk.name}` is already running."
      msg += "Have you forgot to exit bin/console?" if $PROGRAM_NAME != "bin/console"

      if ENV["ENV"] == "production" && $PROGRAM_NAME != "bin/console"
        raise msg
      else
        LOGGER.warn msg
      end
    end

    def stop_proxies
      system("scripts/keydesk_proxy_stop.sh")
    end
  end

  def launch_proxy
    conf = decoded_ss_link

    system(
      "scripts/keydesk_proxy_start.sh",
      name,
      conf["server"],
      conf["server_port"],
      conf["password"],
      conf["method"],
      proxy_port
    )
  end

  def stop_proxy
    raise "Not implemented!"
  end

  def proxy_url
    "socks5://127.0.0.1:#{proxy_port}"
  end

  def proxy_port
    (10000 + id).to_s
  end

  # AI atrocity
  def decoded_ss_link
    url = ss_link.sub(/^ss:\/\//, "")
    url_main, _ = url.split("#", 2)

    if url_main.include?("@")
      creds_base64, rest = url_main.split("@", 2)
      method_password = Base64.decode64(creds_base64)
      method, password = method_password.split(":", 2)
      server, port = rest.split(":", 2)
    else
      method_password_server = Base64.decode64(url_main)
      method, rest = method_password_server.split(":", 2)
      password, serverport = rest.split("@", 2)
      server, port = serverport.split(":", 2)
    end

    port = port&.split(/[\/\?#]/,2)[0]

    {
      "method"      => method,
      "password"    => password,
      "server"      => server,
      "server_port" => port
    }
  end
end
