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

ActiveRecord::Schema[7.1].define(version: 2025_09_09_042732) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "admin_logs", force: :cascade do |t|
    t.bigint "admin_user_id"
    t.string "action", null: false
    t.text "details", null: false
    t.string "target_type"
    t.bigint "target_id"
    t.string "ip_address", null: false
    t.text "user_agent"
    t.text "additional_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_admin_logs_on_action"
    t.index ["admin_user_id"], name: "index_admin_logs_on_admin_user_id"
    t.index ["created_at"], name: "index_admin_logs_on_created_at"
    t.index ["ip_address"], name: "index_admin_logs_on_ip_address"
    t.index ["target_type", "target_id"], name: "index_admin_logs_on_target_type_and_target_id"
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.integer "status", default: 0
    t.bigint "role_id", null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["role_id"], name: "index_admin_users_on_role_id"
    t.index ["status"], name: "index_admin_users_on_status"
  end

  create_table "automations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "instagram_account_id", null: false
    t.string "name", null: false
    t.string "trigger_keyword", null: false
    t.text "response_message", null: false
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["instagram_account_id"], name: "index_automations_on_instagram_account_id"
    t.index ["user_id"], name: "index_automations_on_user_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "instagram_username", null: false
    t.string "instagram_user_id", null: false
    t.string "full_name"
    t.text "bio"
    t.integer "followers_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "instagram_user_id"], name: "index_contacts_on_user_id_and_instagram_user_id", unique: true
    t.index ["user_id"], name: "index_contacts_on_user_id"
  end

  create_table "instagram_accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "instagram_user_id", null: false
    t.string "username", null: false
    t.text "access_token", null: false
    t.datetime "token_expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "account_type", default: "PERSONAL"
    t.integer "media_count", default: 0
    t.datetime "connected_at"
    t.index ["user_id", "instagram_user_id"], name: "index_instagram_accounts_on_user_id_and_instagram_user_id", unique: true
    t.index ["user_id"], name: "index_instagram_accounts_on_user_id"
  end

  create_table "links", force: :cascade do |t|
    t.string "title", null: false
    t.string "url", null: false
    t.text "description"
    t.integer "position", default: 0
    t.boolean "active", default: true
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "active"], name: "index_links_on_user_id_and_active"
    t.index ["user_id", "position"], name: "index_links_on_user_id_and_position"
    t.index ["user_id"], name: "index_links_on_user_id"
  end

  create_table "permissions", force: :cascade do |t|
    t.string "name", null: false
    t.string "resource", null: false
    t.string "action", null: false
    t.text "description", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_permissions_on_action"
    t.index ["name"], name: "index_permissions_on_name", unique: true
    t.index ["resource", "action"], name: "index_permissions_on_resource_and_action", unique: true
    t.index ["resource"], name: "index_permissions_on_resource"
  end

  create_table "role_permissions", force: :cascade do |t|
    t.bigint "role_id", null: false
    t.bigint "permission_id", null: false
    t.boolean "granted", default: true
    t.text "conditions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["granted"], name: "index_role_permissions_on_granted"
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
    t.index ["role_id", "permission_id"], name: "index_role_permissions_on_role_id_and_permission_id", unique: true
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name", null: false
    t.text "description", null: false
    t.string "color", null: false
    t.integer "priority", null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_roles_on_active"
    t.index ["name"], name: "index_roles_on_name", unique: true
    t.index ["priority"], name: "index_roles_on_priority", unique: true
  end

  create_table "usage_metrics", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "metric_type", null: false
    t.integer "count", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "metric_type", "created_at"], name: "index_usage_metrics_on_user_id_and_metric_type_and_created_at"
    t.index ["user_id"], name: "index_usage_metrics_on_user_id"
  end

  create_table "user_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "admin_user_id"
    t.string "action", null: false
    t.text "details", null: false
    t.string "ip_address"
    t.text "user_agent"
    t.text "additional_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_user_logs_on_action"
    t.index ["admin_user_id"], name: "index_user_logs_on_admin_user_id"
    t.index ["created_at"], name: "index_user_logs_on_created_at"
    t.index ["user_id", "action"], name: "index_user_logs_on_user_id_and_action"
    t.index ["user_id", "created_at"], name: "index_user_logs_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_user_logs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "first_name"
    t.string "last_name"
    t.integer "plan", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "referral_code"
    t.integer "referred_by"
    t.decimal "referral_earnings", precision: 10, scale: 2, default: "0.0"
    t.integer "total_referrals", default: 0
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["referral_code"], name: "index_users_on_referral_code", unique: true
    t.index ["referred_by"], name: "index_users_on_referred_by"
  end

  add_foreign_key "admin_logs", "admin_users"
  add_foreign_key "admin_users", "roles"
  add_foreign_key "automations", "instagram_accounts"
  add_foreign_key "automations", "users"
  add_foreign_key "contacts", "users"
  add_foreign_key "instagram_accounts", "users"
  add_foreign_key "links", "users"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "usage_metrics", "users"
  add_foreign_key "user_logs", "admin_users"
  add_foreign_key "user_logs", "users"
end
