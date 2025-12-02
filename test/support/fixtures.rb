module Fixtures
  def user(tg_id: 1, n_keys: 0, pending_config_until: nil, rules_read: true, admin: false, state: nil, role: 0)
    @user ||= User.create(
      tg_id:,
      n_keys:,
      pending_config_until:,
      rules_read:,
      admin:,
      state:,
      role:,
      **attrs
    )
  end

  def keydesk(
    ss_link: "https://dummy.link",
    n_keys: 0,
    max_keys: 250,
    name: "Test",
    status: 0,
    error_count: 0,
    last_error_at: nil,
    usernames_to_destroy: nil,
    **attrs
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
      **attrs
    )
  end
end