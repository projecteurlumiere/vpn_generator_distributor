require "sequel"

DB = Sequel.sqlite("db/db.sqlite3",
                   logger: LOGGER)

DB.create_table? :users do
  primary_key :id
  Integer :tg_id # TG user id
  Integer :n_keys
end

DB.create_table? :keydesks do
  primary_key :id
  String :ss_link
  Integer :n_keys
  String :name
end

DB.create_table? :keys do
  primary_key :id
  foreign_key :user_id, :users
  foreign_key :keydesk_id, :keydesks
  String :keydesk_username
  String :personal_note
end
