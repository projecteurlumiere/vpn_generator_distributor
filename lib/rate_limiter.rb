# 30 messages per second for all users
# 20 messages per minute for a group
# 1 message per second to a particular user

class RateLimiter
  def initialize(interval)
    @interval = interval
    @queues = Hash.new { |hash, key| hash[key] = [] }
    @new_jobs = Concurrent::Array.new

    worker_loop
  end

  def execute(id, &block)
    event = Concurrent::Event.new
    @new_jobs << [id, block, event]
    event.wait
  end

  private

  def worker_loop
    Async do
      while true
        while @new_jobs.shift in [id, block, event]
          @queues[id] << [block, event]
        end

        @queues.reject! do |id, jobs|
          next true unless jobs.shift in [block, event]

          block.call
          event.set
          sleep(@interval)
          false
        end

        Async::Task.current.yield
      end
    end
  end
end
