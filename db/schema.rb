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

ActiveRecord::Schema[7.1].define(version: 2026_01_06_172000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "customizations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "job_title", null: false
    t.string "company", null: false
    t.string "posting_url"
    t.string "platform"
    t.integer "ats_score", default: 0
    t.text "keywords_matched"
    t.text "keywords_missing"
    t.text "resume_content"
    t.json "profile_snapshot"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company"], name: "index_customizations_on_company"
    t.index ["created_at"], name: "index_customizations_on_created_at"
    t.index ["job_title"], name: "index_customizations_on_job_title"
    t.index ["user_id"], name: "index_customizations_on_user_id"
  end

  create_table "resume_versions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "job_title"
    t.string "company"
    t.text "posting_url"
    t.integer "ats_score"
    t.json "keywords_matched"
    t.json "keywords_missing"
    t.text "resume_content"
    t.json "profile_snapshot"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_resume_versions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "first_name"
    t.string "last_name"
    t.integer "plan", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "coin_balance", default: 0
    t.jsonb "profile_data", default: {}
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["profile_data"], name: "index_users_on_profile_data", using: :gin
  end

  add_foreign_key "customizations", "users"
  add_foreign_key "resume_versions", "users"
end
