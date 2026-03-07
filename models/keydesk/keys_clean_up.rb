# frozen_string_literal: true

# Cleaning up inactive & unactivated keys on Keydesks
# and, _consequently_, in the local db
module Keydesk::KeysCleanUp
  NEW_KEY_TIMEOUT = 24 * 60 * 60 # 2 days
  ABANDONED_KEY_TIMEOUT = 24 * 60 * 60 * 182 # half a year

  # Array of usernames and last visit dates (or "-" of none)
  # ["username_1", "2024-09", "username_2", "2024-09", ...]
  def usernames_to_destroy
    (super.nil? && []) || JSON[super]
  end

  def find_usernames_to_destroy!
    list = filter_for_usernames_to_destroy(self.users)

    list = list.flat_map do
      [
        it["UserName"],
        (Date.parse(it["LastVisitHour"]).strftime("%Y-%m") rescue "-")
      ]
    end

    update(usernames_to_destroy: JSON.dump(list))
  end

  def clean_up_keys
    result = usernames_to_destroy.map.with_index do |username, i|
      next if i.odd? # last_visit_hour

      if (key = keys_dataset.where(keydesk_username: username).first)
        key.destroy
      else
        delete_user(username:)
      end

      true
    rescue VpnWorks::Error
      next false
    end

    update(usernames_to_destroy: nil)
    result
  end

  private

  def filter_for_usernames_to_destroy(list)
    reserved_keys = find_reserved_keys.to_set

    list.reject do |user|
      timeouted = if user["Status"] == "black"
                    # created recently
                    Time.parse(user["CreatedAt"]) >= (Time.now - NEW_KEY_TIMEOUT)
                  else
                    # visited recently
                    Time.parse(user["LastVisitHour"]) >= (Time.now - ABANDONED_KEY_TIMEOUT)
                  end

      timeouted || reserved_keys.include?(user["UserName"])
    end
  end

  def find_reserved_keys
    keys_dataset.where do
      (pending_destroy_until =~ nil) &
             (reserved_until !~ nil) &
         (reserved_until > Time.now)
    end.select_map(:keydesk_username)
  end
end
