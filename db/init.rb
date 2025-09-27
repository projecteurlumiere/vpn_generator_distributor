require "sequel"

DB = Sequel.sqlite("db/db.sqlite3",
                   logger: LOGGER)

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
  TrueClass :online, null: false, default: false 
  String :name, unique: true, null: false
end

DB.create_table? :keys do
  primary_key :id
  foreign_key :user_id, :users, null: false
  foreign_key :keydesk_id, :keydesks
  String :keydesk_username, null: false
  String :desc
  DateTime :pending_destroy_until
  DateTime :reserved_until
  DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
end
