# frozen_string_literal: true

# We patch bot API with this
# Telegram limits:
# 30 messages per second for all users
# 20 messages per minute for a group
#  1 message per second to a particular user
class Bot::RateLimiter
  def initialize(interval)
    @interval = interval
    @queues = Hash.new { |hash, key| hash[key] = [] }
    @new_jobs = []
    @job_available = Async::Notification.new

    process_jobs
  end

  def execute(id)
    job_start = Async::Notification.new
    @new_jobs << [id, job_start]
    @job_available.signal
    job_start.wait
    yield
  end

  private

  def process_jobs
    Async do
      while true
        @job_available.wait if @queues.none?

        while @new_jobs.shift in [id, job_start]
          @queues[id] << [job_start]
        end

        @queues.reject! do |_id, jobs|
          next true unless jobs.shift in [job_start]

          job_start.signal

          sleep(@interval)
          false
        end
      end
    end
  end
end
