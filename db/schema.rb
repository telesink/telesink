# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_17_124113) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "columns", force: :cascade do |t|
    t.jsonb "config"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.bigint "sink_id", null: false
    t.datetime "updated_at", null: false
    t.index ["sink_id", "position"], name: "index_columns_on_sink_id_and_position"
    t.index ["sink_id"], name: "index_columns_on_sink_id"
  end

  create_table "events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "emoji", limit: 8, default: "📌", null: false
    t.string "event_type", null: false
    t.string "idempotency_key"
    t.datetime "occurred_at", null: false
    t.jsonb "properties", default: {}, null: false
    t.string "sdk_name"
    t.string "sdk_version"
    t.bigint "sink_id", null: false
    t.text "text", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_events_on_event_type"
    t.index ["properties"], name: "index_events_on_properties", using: :gin
    t.index ["sink_id", "idempotency_key"], name: "index_events_on_sink_id_and_idempotency_key", unique: true
    t.index ["sink_id", "occurred_at"], name: "index_events_on_sink_id_and_occurred_at", order: { occurred_at: :desc }
    t.index ["sink_id"], name: "index_events_on_sink_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "sink_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "sink_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["sink_id"], name: "index_sink_memberships_on_sink_id"
    t.index ["user_id", "sink_id"], name: "index_sink_memberships_on_user_id_and_sink_id", unique: true
    t.index ["user_id"], name: "index_sink_memberships_on_user_id"
  end

  create_table "sinks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "token"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_sinks_on_name"
    t.index ["token"], name: "index_sinks_on_token", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "columns", "sinks"
  add_foreign_key "events", "sinks"
  add_foreign_key "sessions", "users"
  add_foreign_key "sink_memberships", "sinks"
  add_foreign_key "sink_memberships", "users"
end
