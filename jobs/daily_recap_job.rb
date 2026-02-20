# frozen_string_literal: true

# Sends statistics to the admin chat once per day
class DailyRecapJob < ApplicationJob
  include DummyController

  PERFORM_AT = 18 # UTC hour

  def perform_now(bot)
    LOGGER.info "The daily recap for today:\n#{log_message}"

    controller = generate_dummy_controller(bot)
    controller.send(:reply, message, chat_id: Bot::ADMIN_CHAT_ID, parse_mode: "Markdown")
  end

  # recap message formatted for logging purposes
  def log_message
    msg = message.lines.filter_map do |line|
      case line
      when /\`|🤖/
        next
      when /\_/
        line.prepend("\n")
      when /\*/
        line.delete_suffix!("\n")
      end

      line.gsub!(/[_\*]/i, "")
      line.squeeze! unless line.match?(/\d/)

      line
    end.join

    msg.prepend("-" * 33)
    msg << "-" * 33
  end

  private

  # keep tables under two lines to avoid `copy` button in the UI
  def message
    @message ||= <<~TXT
      🤖 Отчёт за #{Date.today.strftime("%d.%m.%Y")}

      *🔑 Ключи*

      _Ключей за сутки:_
      ```
      #{rows("Выдано", n_issued_keys_today, "Зарезервировано", n_reserved_keys_today)}
      ```
      _Ключей не выдано из-за ошибок:_
      ```
      #{rows("За сутки", key_errors[:else])}
      ```
      _Отказов в выдаче ключей за сутки:_
      ```
      #{rows("Нет мест", key_errors[:full], "Не в сети", key_errors[:offline])}
      ```

      *🖥️ Ключницы*

      _Ключниц c проблемами сейчас:_
      ```
      #{rows("Не в сети", offline_keydesks, "Проблемных", unstable_keydesks)}
      ```
      _Ключниц в порядке сейчас:_
      ```
      #{rows("В сети", online_keydesks, "Выдающих ключи", online_and_available_keydesks)}
      ```
      _Мест осталось всего:_
      ```
      #{rows("Минимум", free_n_keys, "Максимум", free_max_n_keys)}
      ```

      *👥 Пользователи*

      _Уникальных пользователей:_
      ```
      #{rows("За сутки", n_users_today)}
      ```
    TXT
  end

  def rows(*pairs)
    pairs.each_slice(2).map { |k, v| "%-15s %6s" % [k, v] }.join("\n")
  end

  def n_issued_keys_today
    Key.where((Sequel[:created_at] >= yesterday) & (Sequel[:reserved_until] =~ nil)).count
  end

  def n_reserved_keys_today
    Key.where((Sequel[:created_at] >= yesterday) & (Sequel[:reserved_until] !~ nil)).count
  end

  def key_errors
    return @errors if @errors

    @errors = {
      total:   0,
      full:    0,
      offline: 0,
      else:    0
    }

    log_files = Dir.entries("./tmp").select { it.match? /\A#{ENV["ENV"]}\.log/io }.reverse

    log_files.each do |name|
      file = File.new("./tmp/#{name}")

      file.readlines.each do |line|
        time = Time.parse(line) rescue next
        next if time < yesterday

        case line
        in /keydesks are offline/
          @errors[:offline] += 1
        in /keydesks are full/
          @errors[:full] += 1
        in /Could not issue key to a user/
          @errors[:else] += 1
        else
          next
        end

        @errors[:total] += 1
      end
    end

    @errors
  end

  def offline_keydesks
    Keydesk.where(status: 0).count
  end

  def unstable_keydesks
    Keydesk.where { (status =~ 1) & (error_count < 5) }.count
  end

  def online_keydesks
    Keydesk.where { (status =~ 2) | ((status =~ 1) & (error_count < 5)) }.count
  end

  def online_and_available_keydesks
    Keydesk.where { (status =~ 2) | ((status =~ 1) & (error_count < 5)) }
           .where { n_keys < Keydesk::MAX_USERS }
           .where { max_keys > 0} # if set to 0, we ignore it even for admins
           .count
  end

  def free_n_keys
    DB[:keydesks].sum(:max_keys) - DB[:keydesks].sum(:n_keys)
  end

  def free_max_n_keys
    Keydesk.count * Keydesk::MAX_USERS - DB[:keydesks].sum(:n_keys)
  end

  def n_users_today
    User.where(Sequel[:last_visit_at] >= yesterday).count
  end

  def yesterday
    @yesterday ||= Time.now - 86_400
  end
end
