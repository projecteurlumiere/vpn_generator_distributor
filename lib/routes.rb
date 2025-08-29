require "singleton"

# require all controllers at boot
Dir[File.join(__dir__, "../controllers/*.rb")].sort.each { |f| require f }

class Routes
  include Singleton

  attr_reader :routes

  def build!
    @routes = { command: {}, callback: {} }
    ApplicationController.subclasses.each do |klass|
      klass.routes.each do |route|
        if offending_klass = @routes[:command][route]
          raise "Route `#{route}` is already handled by #{offending_klass}, cannot assign to #{klass}"
        else
          @routes[:command][route] = klass
        end
      end
    end
  end

  def [](type)
    @routes[type]
  end

  def all
    @routes
  end
end
