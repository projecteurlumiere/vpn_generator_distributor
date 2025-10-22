class Routes
  class ControllerNotFoundError < StandardError; end
  
  Dir[File.join(__dir__, "../controllers/**/*.rb")].sort.each { |f| require f }

  include Singleton

  attr_reader :routes

  def build!
    @routes = { command: {}, callback: {} }
    @controllers = all_subclasses(ApplicationController)

    @controllers.each do |klass|
      klass.routes&.each do |route|
        # if offending_klass = @routes[:command][route]
        #   raise "Route `#{route}` is already handled by #{offending_klass}, cannot assign to #{klass}"
        # else
          # @routes[:command][route] = klass
        # end
        @routes[:command][route] ||= []
        @routes[:command][route] << klass
      end
    end

    [@routes, @controller].map(&:freeze)
  end

  def dispatch_controller(bot, message)
    case message
    in Telegram::Bot::Types::Message if message.chat.id == Bot::ADMIN_CHAT_ID
      Admin::SupportTopicsController.new(bot, message).call
    in Telegram::Bot::Types::Message
      handle_message(bot, message)
    in Telegram::Bot::Types::CallbackQuery
      handle_callback_query(bot, message)
    in Telegram::Bot::Types::ChatMemberUpdated
      ApplicationController.new(bot, message).send(:reply, "Я подключился успешно.")
    end
  rescue ControllerNotFoundError => e
    LOGGER.error "ControllerNotFoundError: #{e.message}"

    msg = <<~TXT
      Не получилось выполнить действие.
      Если вы потерялись, вернуться можно нажав на /start
    TXT
    ApplicationController.new(bot, message).send(:reply, msg, reply_markup: nil)
  end

  def [](type)
    @routes[type]
  end

  def all
    @routes
  end

  private

  def handle_message(bot, message)
    type = :command
    method = :call

    key = message.text
    args = []

    klasses = Routes.instance[type][key] || []

    if klasses.none? &&
       (current_user = ApplicationController.new(bot, message).send(:current_user)) &&
       current_user.state_array.any?
      current_user.state_array => [controller_name, *]

      klass = @controllers.find do |controller|
        controller.name == controller_name
      end

      klasses << klass
    end

    klasses.each do |klass|
      break if klass.nil?

      begin
        controller = klass.new(bot, message)
        controller.instance_variable_set(:@current_user, current_user) if defined? current_user
        return controller.send(method)
      rescue ApplicationController::RoutingError => e
        next
      end
    end

    msg = [
      "Could not execute any controller action",
      (klasses.any? ? "in #{klasses}" : "no Controller class found"),
      "inferred from `#{message.text}`",
      ("and user's state '#{user_state}'" if defined?(user_state))
    ].compact.join(" ")
    raise ControllerNotFoundError, msg
  end

  def handle_callback_query(bot, message)
    type = :callback
    message.data.split("|") => [klass_name, method, *args]

    klass = @controllers.find do |controller|
      controller.name == klass_name
    end

    if klass.nil?
      raise ControllerNotFoundError, "Could not find controller `#{klass_name}` inferred from #{message.data}"
    end


    unless klass.method_defined?(method)
      raise ControllerNotFoundError, "Could not find method `#{method}` in controller `#{klass_name}` inferred from #{message.data}"
    end

    klass.new(bot, message)
         .send(method, *args)
  end

  def all_subclasses(klass)
    klass.subclasses.flat_map { |sub| [sub, *all_subclasses(sub)] }
  end
end
