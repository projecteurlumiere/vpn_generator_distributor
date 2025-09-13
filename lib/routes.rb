require "singleton"

# require all controllers at boot
Dir[File.join(__dir__, "../controllers/**/*.rb")].sort.each { |f| require f }

class Routes
  class ControllerNotFoundError < StandardError; end

  include Singleton

  attr_reader :routes

  def build!
    @routes = { command: {}, callback: {} }
    ApplicationController.subclasses.each do |klass|
      klass.routes.each do |route|
        # if offending_klass = @routes[:command][route]
        #   raise "Route `#{route}` is already handled by #{offending_klass}, cannot assign to #{klass}"
        # else
          # @routes[:command][route] = klass
        # end
        @routes[:command][route] ||= []
        @routes[:command][route] << klass
      end
    end
  end

  def dispatch_controller(bot, message)
    case message
    in Telegram::Bot::Types::Message
      type = :command
      method = :call

      key = message.text
      args = []
    # in Telegram::Bot::Types::CallbackQuery
    #   raise "Handling CallbackQuery type of messages is not implemented!"
    #   type = :callback
    #   message.data.split("_") => [key, method, *args]
    end

    
    klasses = Routes.instance[type][key] || []

    if klasses.none? && 
       (current_user = ApplicationController.new(bot, message).send(:current_user)) &&
       current_user.state_array.any?
      current_user.state_array => [controller_name, *]
      klass = ApplicationController.subclasses.find do |controller|
        controller.name == controller_name
      end

      klasses << klass
    end

    klasses.each do |klass|
      begin
        controller = klass.new(bot, message)
        controller.instance_variable_set(:@current_user, current_user) if defined? current_user
        return controller.send(method)
      rescue NoMatchingPatternError, ApplicationController::RoutingError => e
        next
      end 
    end

    msg = "Could not execute any controller action in #{klasses} inferred from #{message.text}"
    msg += " and user's state '#{user_state}'" if defined?(user_state)
    raise ControllerNotFoundError, msg
  end

  def [](type)
    @routes[type]
  end

  def all
    @routes
  end
end
