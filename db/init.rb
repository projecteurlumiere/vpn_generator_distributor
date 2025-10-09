require "sequel"
require "pg"

# before altering the table after launch, implement migrations!

if ENV["ENV"] == "development"
  DB = Sequel.connect(
    adapter: "postgres",
    database: "vpn_distributor_development",
    user: ENV["USER"],
    logger: LOGGER
  )
else
  raise "not implemented!"
end

DB.create_table? :users do
  primary_key :id
  Integer :tg_id, unique: true, null: false # TG user id
  Integer :n_keys, default: 0, null: false
  DateTime :pending_config_until
  TrueClass :rules_read, default: false, null: false
  TrueClass :admin, default: false, null: false
  String :state
end

DB.create_table? :keydesks do
  primary_key :id
  String :ss_link, unique: true, null: false
  Integer :n_keys, default: 0, null: false
  Integer :max_keys, null: false
  String :name, unique: true, null: false
  # errors & status
  Integer :status, null: false, default: 0
  Integer :error_count, null: false, default: 0
  DateTime :last_error_at
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
  Integer :status, null: false, default: 0
  DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
end
