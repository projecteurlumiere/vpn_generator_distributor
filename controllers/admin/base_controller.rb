class Admin::BaseController < ApplicationController
  def initialize(...)
    super
  end

  def admin_menu_inline_button
    {
      "В меню" => callback_name(Admin::MenuController, "menu")
    }
  end
end
