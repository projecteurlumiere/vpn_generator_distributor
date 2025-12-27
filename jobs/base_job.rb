# frozen_string_literal: true

class BaseJob
  def self.run_async(*args)
    Async do
      while true
        if ENV["ENV"] == "production"
          sleep 3600
          next unless Time.now.utc.hour == PERFORM_AT
        else
          sleep 60
        end

        LOGGER.info "Starting job: #{self}"

        begin
          self.new.perform_now(*args)
        rescue StandardError => e
          LOGGER.error "Error when performing job: #{self}: #{e.message}\n#{e.backtrace.join("\n")}"
        end

        LOGGER.info "Job finished: #{self}"
      end
    end
  end
end
