# frozen_string_literal: true

# Sending out :about to users who haven't received it after receiving their key
class RestartUnstableKeydesksJob < Bot::Job
  PERFORM_EVERY = ENV["ENV"] == "development" ? 30 : 3600 # 1 hour

  def perform_now
    Keydesk.where { (status =~ 1) & (error_count >= 5) }.all.each do |kd|
      kd.stop_proxy
      kd.start_proxy
      LOGGER.info "Restarted proxy `#{kd.name}`"
    rescue StandardError => e
      LOGGER.warn "Error when restarting Keydesk `#{kd.name}`. #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end
end
