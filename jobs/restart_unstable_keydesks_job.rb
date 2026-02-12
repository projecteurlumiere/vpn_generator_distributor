# frozen_string_literal: true

# unstable keydesks are subject to regular restarts until the connection is established
class RestartUnstableKeydesksJob < Bot::Job
  PERFORM_EVERY = ENV["ENV"] == "development" ? 30 : 3600 # 1 hour

  def perform_now
    Keydesk.where { (status =~ 1) & (error_count >= 5) }.all.each do |kd|
      status, error_count = kd.status, kd.error_count

      kd.stop_proxy
      kd.start_proxy
      LOGGER.info "Restarted proxy `#{kd.name}`"
    rescue StandardError => e
      LOGGER.warn "Error when restarting Keydesk `#{kd.name}`. #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
      kd.update(status:, error_count:) # to ensure it keeps rebooting
    end
  end
end
