# frozen_string_literal: true

# This patch counts update IDs to avoid processing of duplicate requests

module Telegram
  module Bot
    class Client
      def listen(&block)
        logger.info('Starting bot')
        @running = true
        begin
          fetch_updates(&block) while @running
        rescue => e
          logger.error("Error fetching updates. #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")
          retry if @running
        end
      end

      def fetch_updates
        api.getUpdates(options).each do |update|
          logger.debug "update_id: #{update.update_id}"
          logger.warn "Skipping update_id `#{update.update_id}`: update has already been processed" and next if update_processed?(update.update_id)

          yield handle_update(update)
        end
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
        retry if @running
      rescue Faraday::SSLError => e
        raise unless e.message.include?('SSL_read: unexpected eof while reading')

        logger.error "Faraday SSL error: #{e.class}, #{e.message}"
        retry if @running
      end

      private

      #
      # Removing duplicate updates (is this even a problem?)
      #

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
