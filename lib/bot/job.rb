# frozen_string_literal: true

class Bot::Job
  class << self
    def run_async(*args)
      Async do
        @running = true

        timeout = ENV["ENV"] == "production" ? 3600 : 60
        since_timeout = 0
        while @running
          since_timeout += 1 and sleep 1 and next if since_timeout < timeout

          since_timeout = 0

          next if ENV["ENV"] == "production" && Time.now.utc.hour != PERFORM_AT

          LOGGER.info "Starting job: #{self}"

          begin
            self.new.perform_now(*args)
          rescue StandardError => e
            LOGGER.error "Error when performing job: #{self}: #{e.message}\n#{e.backtrace.join("\n")}"
          end

          LOGGER.info "Job finished: #{self}"
        end

        LOGGER.debug "Job scheduler gracefully shut down for #{self}"
      end

      def stop
        @running = false
      end
    end
  end
end
