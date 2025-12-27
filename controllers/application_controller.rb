class ApplicationController < BaseController
  class RoutingError < StandardError; end
  class NotAuthorizedError < StandardError; end

  def initialize(...)
    super

    return unless account_for_visit
    raise NotAuthorizedError unless is_authorized?
  end

  private

  # skipping double actions if they are within 0.25sec
  def account_for_visit
    User.where(tg_id:)
        .where { last_visit_at < (Time.now - 0.25) }
        .update(last_visit_at: Time.now) == 1
  end

  # override
  def is_authorized?
    true
  end

  # name - Symbol
  def reply_slide(name)
    slide = Slides.instance[name]
    reply_with_buttons(slide[:text], [slide[:actions]], photos: slide[:images], parse_mode: "Markdown")
  end

  def current_user
    @current_user ||= User.find(tg_id:) || User.create(tg_id:)
    @current_user.update(chat_id:) if @current_user.chat_id.nil? && chat_id.positive?
    @current_user
  end

  def callback_name(*args)
    args.unshift(self.class.name) if args[0].instance_of?(String)

    name = args.join("|")
    raise "Callback cannot have bytezise more than 64" if name.bytesize > 64

    name
  end

  def escape_md_v2(text)
    text.gsub(/([_\*\[\]\(\)~`>#+\-=|{}\.!])/, '\\\\\1')
  end

  def first_name
    message.from.first_name
  end

  def last_name
    message.from&.last_name
  end
end
