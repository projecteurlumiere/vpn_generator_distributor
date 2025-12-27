# frozen_string_literal: true

class Routes
  include Singleton

  class ControllerNotFoundError < StandardError; end

  Dir[File.join(__dir__, "../controllers/**/*.rb")].sort.each { |f| require f }

  attr_reader :routes

  def initialize
    build!
  end

  def build!
    @routes = { command: Hash.new { |h, k| h[k] = [] } }
    @controllers = all_subclasses_of(ApplicationController)

    @controllers.each do |klass|
      klass.routes.each do |route|
        @routes[:command][route] << klass
      end
    end

    [@routes, @controllers].map(&:freeze)
  end

  def [](type)
    @routes[type]
  end

  # { command: { "/start" => [StartController], "Back" => [StartController, InstructionsController], ... } }
  def all
    @routes
  end

  def dispatch_controller(bot, message)
    if group_message?(message) && message.chat.id != Bot::ADMIN_CHAT_ID
      reply_to_group(bot, message)
      return
    end

    case message
    in Telegram::Bot::Types::Message if message.chat.id == Bot::ADMIN_CHAT_ID
      Admin::SupportTopicsController.new(bot, message).call
    in Telegram::Bot::Types::Message
      handle_message(bot, message)
    in Telegram::Bot::Types::CallbackQuery
      handle_callback_query(bot, message)
    else
      LOGGER.warn "Gracefully skipping message:\n#{message.class}\n#{message}"
    end
  rescue StandardError => e
    handle_dispatching_error(bot, message, e)
    raise unless ENV["production"]
  end

  private

  def group_message?(message)
    message.respond_to?(:chat) && message.chat.type != "private"
  end

  def reply_to_group(bot, message)
    LOGGER.warn "Someone used the bot in a group chat that is not the admin chat: #{message.chat.id}"

    if Bot::ADMIN_CHAT_ID.to_i == 0
      controller = BaseController.new(bot, message)
      controller.send(:reply, "No admin chat provided.\nChat id: `#{controller.chat_id}`", parse_mode: "Markdown")
    end
  end

  # Handling regular messages
  # Always uses Controller_class#call
  # Priority:
  # 1) When user in a conversation with support - invoke that controller only
  # 2) Routes predefined in controllers' classes (e.g. `/start`, `/admin`, etc.)
  # 3) Keep deducing the controller from user's state;
  # User's state always starts with the controller_name;
  # When routed by state, controller handles everything individually
  def handle_message(bot, message)
    current_user = BaseController.new(bot, message).send(:current_user)
    controller_from_state  = current_user.state_array.first

    klasses = case controller_from_state
              in "SupportTopicsController" if SupportTopicsController::EXIT_COMMANDS.none?(message&.text)
                [SupportTopicsController]
              in nil
                Routes.instance[:command][message.text]
              else
                [
                  *Routes.instance[:command][message.text],
                  @controllers.find { it.name == controller_from_state }
                ].compact
              end

    klasses.each do |klass|
      controller = klass.new(bot, message)

      # Danger: we inject current_user to avoid multiple requests
      controller.instance_variable_set(:@current_user, current_user)

      return controller.send(:call)
    rescue ApplicationController::RoutingError
      next
    end

    msg = [
      "Could not execute any controller action",
      (klasses.any? ? "in #{klasses}" : "no Controller class found"),
      "inferred from `#{message.text}`",
      ("and user's state: `#{user_state}`" if defined?(user_state))
    ].compact.join(" ")
    raise ControllerNotFoundError, msg
  end

  # Callback queries (in-message buttons) are to call controller methods directly
  # Callback example: `class_name|method_name|args_1|arg_2`
  # Careful: callback string max size is 64 bytes
  def handle_callback_query(bot, message)
    message.data.split("|") => [klass_name, method, *args]

    klass = @controllers.find do |controller|
      controller.name == klass_name
    end

    if klass.nil?
      raise ControllerNotFoundError,
            "Could not find controller `#{klass_name}` inferred from `#{message.data}`"
    end

    unless klass.method_defined?(method)
      raise ControllerNotFoundError,
            "Could not find method `#{method}` in controller `#{klass_name}` inferred from `#{message.data}`"
    end

    klass.new(bot, message).public_send(method, *args)
  end

  def handle_dispatching_error(bot, message, e)
    if ENV["ENV"] == "production"
      LOGGER.error "Error when dispatching controller: #{e.class}\n#{e.full_message}\n#{e.backtrace}"
    end

    controller = BaseController.new(bot, message)

    msg = case e
          in ApplicationController::TooManyRequestsError
            raise "Not Implemented!"
          in ApplicationController::NotAuthorizedError
            <<~TXT
              У вас нет прав для выполнения этого действия.
              Если вы потерялись, вернуться можно нажав на /start
            TXT
          in ControllerNotFoundError
            <<~TXT
              Не получилось выполнить действие.
              Если вы потерялись или хотите связаться с поддержкой, нажмите /start
            TXT
          else
            case controller.chat_id
            in ^(Bot::ADMIN_CHAT_ID)
              "⚠️ Что-то пошло не так: #{e.class}"
            else
              "Что-то пошло не так.\nЕсли вы потерялись, вернуться можно нажав на /start"
            end
          end

    controller.send(:reply, msg, reply_markup: nil) rescue LOGGER.error "Unable to report error to user"
  end

  def all_subclasses_of(klass)
    klass.subclasses.flat_map { |sub| [sub, *all_subclasses_of(sub)] }
  end
end
