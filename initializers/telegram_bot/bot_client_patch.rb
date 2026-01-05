# frozen_string_literal: true

# This patch counts update IDs to avoid processing of duplicate requests

module Telegram
  module Bot
    class Client
      def fetch_updates
        api.getUpdates(options).each do |update|
          next if update_processed?(update.update_id)

          yield handle_update(update)
        end
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
        # if the error of bot dying silently happens here, add method for resetting `connection` in `Api` class
        logger.error("Faraday error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
        retry if @running
      rescue => e
        logger.error("Unhandled error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
        retry if @running
      end

      private

      # put those in init later:
      UPDATES     = []
      UPDATES_SET = Set[]

      def update_processed?(id)
        reset_update_ids if requires_resetting_ids?

        return true unless UPDATES_SET.add?(id)

        @last_update_at = Time.now
        UPDATES << id
        UPDATES_SET.delete(UPDATES.shift) if UPDATES.size > 100

        false
      end

      # To quote the docs:
      # If there are no new updates for at least a week, then identifier of the next update will be chosen randomly instead of sequentially.
      def requires_resetting_ids?
        (Time.now - (@last_update_at || Time.at(0))) >= 604_800 # one week
      end

      def reset_update_ids
        UPDATES.clear
        UPDATES_SET.clear
      end
    end
  end
end
