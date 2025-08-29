require "sequel"

DB = Sequel.sqlite("db/db.sqlite3",
                   logger: LOGGER)

DB.create_table? :users do
  primary_key :id
  Integer :tg_id, null: false # TG user id
  Integer :n_keys, default: 0, null: false
  DateTime :pending_config_until
  TrueClass :rules_read, default: false, null: false
  String :instruction
  Integer :instruction_step
end

DB.create_table? :keydesks do
  primary_key :id
  String :ss_link, null: false
  Integer :n_keys, default: 0, null: false
  String :name, null: false
end

DB.create_table? :keys do
  primary_key :id
  foreign_key :user_id, :users
  foreign_key :keydesk_id, :keydesks
  String :keydesk_username, null: false
  String :personal_note, null: false
  DateTime :pending_destroy_until
end
