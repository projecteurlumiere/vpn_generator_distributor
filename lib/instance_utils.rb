module InstanceUtils
  def self.record
    FileUtils.mkdir_p "./tmp/instances"
    path = "./tmp/instances/#{Process.pid}.pid"

    at_exit do
      File.delete(path) if File.exist?(path)
    end

    File.write(path, "")
  end

  def self.number
    @number ||= Dir["./tmp/instances/*.pid"].count do |f|
      pid = f[/\d+/].to_i
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      File.delete(f)
      false
    end
  end
end
