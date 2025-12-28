module Fixtures
  def user(**args)
    @user ||= create_user(**args)
  end

  def create_user(tg_id: 1, n_keys: 0, pending_config_until: nil, rules_read: true, state: nil, role: 0)
    User.create(
      tg_id:,
      n_keys:,
      pending_config_until:,
      rules_read:,
      state:,
      role:,
    )
  end

  def keydesk(**args)
    @keydesk ||= create_keydesk(**args)
  end

  def create_keydesk(
    ss_link: "https://dummy.link",
    n_keys: 0,
    max_keys: 250,
    name: "Test",
    status: 2,
    error_count: 0,
    last_error_at: nil,
    usernames_to_destroy: nil
  )
    Keydesk.create(
      ss_link:,
      n_keys:,
      max_keys:,
      name:,
      status:,
      error_count:,
      last_error_at:,
      usernames_to_destroy:,
    )
  end
end