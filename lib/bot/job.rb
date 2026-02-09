# frozen_string_literal: true

class Bot::Job
  class << self
    def run_async(...)
      if defined? self::PERFORM_AT
        LOGGER.info "Periodic job #{self} will be performed at #{self::PERFORM_AT}:00 UTC"
        run_at(...)
      elsif defined? self::PERFORM_EVERY
        LOGGER.info "Periodic job #{self} will be performed every #{self::PERFORM_EVERY} seconds"
        run_every(...)
      else
        LOGGER.warn "Job #{self} will NOT be performed periodically"
      end
    end

    def run_at(...)
      Async do
        @running = true

        timeout = ENV["ENV"] == "production" ? 3600 : 60
        since_timeout = 0

        while @running
          since_timeout += 1
          sleep 1 and next if since_timeout < timeout

          next if ENV["ENV"] == "production" && Time.now.utc.hour != self::PERFORM_AT

          since_timeout = 0

          dispatch_job(...)
        end

        LOGGER.debug "Job scheduler gracefully shut down for #{self}"
      end

      def run_every(...)
        Async do
          @running = true

          next_perform = Time.now + self::PERFORM_EVERY

          while @running
            if Time.now < next_perform
              sleep 1
              next
            else
              next_perform = Time.now + self::PERFORM_EVERY
            end

            dispatch_job(...)
          end
        end
      end

      def dispatch_job(...)
        LOGGER.info "Starting job: #{self}"

        begin
          self.new.perform_now(...)
        rescue StandardError => e
          LOGGER.error "Error when performing job: #{self}: #{e.message}\n#{e.backtrace.join("\n")}"
        end

        LOGGER.info "Job finished: #{self}"
      end
    end

    def stop
      @running = false
    end
  end
end
