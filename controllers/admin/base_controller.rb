class Admin::BaseController < ApplicationController
  def is_authorized?
    Bot::ADMIN_IDS.any?(tg_id)
  end

  def admin_menu_inline_button
    {
      "В меню" => callback_name(Admin::MenuController, "menu")
    }
  end
end
