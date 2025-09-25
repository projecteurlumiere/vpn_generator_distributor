module AdminHelpers
  def initialize(...)
    super
  end

  def admin_menu_inline_button
    {
      "В меню" => callback_name(Admin::BaseController, "menu")
    }
  end
end