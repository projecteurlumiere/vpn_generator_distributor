# frozen_string_literal: true

# Sending out :about to users who haven't received it after receiving their key
class DailyRecapJob < ApplicationJob
  include DummyController

  PERFORM_AT = 18 # UTC hour

  def perform_now(bot)
    controller = generate_dummy_controller(bot)
    controller.send(:reply, recap_message, chat_id: Bot::ADMIN_CHAT_ID, parse_mode: "Markdown")
  end

  private

  def recap_message
    <<~TXT
      🤖 Отчёт за #{Date.today.strftime("%d.%m.%Y")}

      *Ключей за сутки:*
      ```
      #{table_section([["Выдано", n_issued_keys_today], ["Зарезервировано", n_reserved_keys_today]])}
      ```

      *Ключниц:*
      ```
      #{table_section([["Оффлайн", offline_keydesks], ["Проблемных", unstable_keydesks]])}
      ```

      *Мест осталось:*
      ```
      #{table_section([["Минимум", free_n_keys], ["Максимум", free_max_n_keys]])}
      ```
    TXT
  end

  def table_section(pairs)
    pairs.map { |k, v| "%-15s %6s" % [k, v] }.join("\n")
  end

  def n_issued_keys_today
    Key.where { (created_at >= Time.now - 86_400) & reserved_until =~ nil}.count
  end

  def n_reserved_keys_today
    Key.where { (created_at >= Time.now - 86_400) & (reserved_until !~ nil) }.count
  end

  def offline_keydesks
    Keydesk.where(status: 0).count
  end

  def unstable_keydesks
    Keydesk.where { (status =~ 1) & (error_count >= 5) }.count
  end

  def free_n_keys
    DB[:keydesks].sum(:max_keys) - DB[:keydesks].sum(:n_keys)
  end

  def free_max_n_keys
    Keydesk.count * Keydesk::MAX_USERS - DB[:keydesks].sum(:n_keys)
  end
end
