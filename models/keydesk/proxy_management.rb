# frozen_string_literal: true

require "base64"

module Keydesk::ProxyManagement
  PROXY_SEMAPHORE = Async::Semaphore.new(1)

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def start_proxies
      tasks = []

      keydesks = Keydesk.all.reject { proxy_running?(it.name, it.proxy_port) && handle_proxy_running }
      Keydesk.dataset.where(id: keydesks.map(&:id)).update(status: 0)

      keydesks.each do |kd|
        tasks << Async do
          kd.start_proxy
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
      msg = "The proxy for `#{name}` is already running."
      msg += " Have you forgot to exit bin/console?" if $PROGRAM_NAME != "bin/console"

      if ENV["ENV"] == "production" && $PROGRAM_NAME != "bin/console"
        raise msg
      else
        LOGGER.warn msg
      end
    end

    def stop_proxies
      Keydesk.all.each { it.stop_proxy }
    end
  end

  def start_proxy
    conf = decoded_ss_link
    args = [
      name,
      conf["server"],
      conf["server_port"],
      conf["password"],
      conf["method"],
      proxy_port
    ]

    args.map! { Shellwords.escape(it.to_s) }

    output = %x[scripts/keydesk_proxy_start.sh #{args.join(" ")}]
    LOGGER.info("#{name} proxy: #{output}")

    sleep 2
    self.update(n_keys: self.users(update_n_keys: false).size,
                error_count: 0,
                last_error_at: nil,
                status: :online)
  rescue VpnWorks::Error => e
    LOGGER.error "Proxy `#{name}` is unreachable after start. #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
  end

  def stop_proxy
    self.update(status: 0)
    output = %x[scripts/keydesk_proxy_stop.sh #{Shellwords.escape(name.to_s)}]
    LOGGER.info("#{name} proxy: #{output}")
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
