require "sequel"

Sequel.extension :fiber_concurrency

DB = Sequel.sqlite("db/db_#{ENV["ENV"]}.sqlite3",
                   logger: LOGGER,
                   timeout: 20000)

DB.create_table? :users do
  primary_key :id
  Integer :tg_id, unique: true, null: false # TG user id
  Integer :chat_id, unique: true # we store our best guess
  Integer :n_keys, null: false, default: 0
  DateTime :pending_config_until
  TrueClass :rules_read, null: false, default: false
  TrueClass :admin, null: false, default: false
  String :state
  Integer :role, null: false, default: 0
end

DB.create_table? :keydesks do
  primary_key :id
  String :ss_link, unique: true, null: false
  Integer :n_keys, null: false, default: 0
  Integer :max_keys, null: false
  String :name, unique: true, null: false
  # errors & status
  Integer :status, null: false, default: 0
  Integer :error_count, null: false, default: 0
  DateTime :last_error_at
  String :usernames_to_destroy
end

DB.create_table? :keys do
  primary_key :id
  foreign_key :user_id, :users, null: false
  foreign_key :keydesk_id, :keydesks, null: false
  String :keydesk_username, null: false
  String :desc
  DateTime :pending_destroy_until
  DateTime :reserved_until
  DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
end

DB.create_table? :support_requests do
  primary_key :id
  foreign_key :user_id, :users, null: false
  DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
  DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
  Integer :status, default: 0
  Integer :message_thread_id
  Integer :user_menu_message_id
end
