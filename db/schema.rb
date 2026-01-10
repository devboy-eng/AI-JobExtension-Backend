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

ActiveRecord::Schema[7.1].define(version: 2026_01_10_154032) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "coin_transactions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "amount", null: false
    t.string "transaction_type", null: false
    t.string "description", null: false
    t.string "razorpay_order_id"
    t.string "razorpay_payment_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["razorpay_order_id"], name: "index_coin_transactions_on_razorpay_order_id"
    t.index ["razorpay_payment_id"], name: "index_coin_transactions_on_razorpay_payment_id"
    t.index ["transaction_type"], name: "index_coin_transactions_on_transaction_type"
    t.index ["user_id", "created_at"], name: "index_coin_transactions_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_coin_transactions_on_user_id"
  end

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

  create_table "payment_orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "razorpay_order_id", null: false
    t.string "razorpay_payment_id"
    t.string "razorpay_signature"
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.integer "coins", null: false
    t.string "currency", default: "INR", null: false
    t.string "receipt"
    t.integer "status", default: 0, null: false
    t.datetime "paid_at"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_payment_orders_on_created_at"
    t.index ["razorpay_order_id"], name: "index_payment_orders_on_razorpay_order_id", unique: true
    t.index ["razorpay_payment_id"], name: "index_payment_orders_on_razorpay_payment_id"
    t.index ["status"], name: "index_payment_orders_on_status"
    t.index ["user_id", "status"], name: "index_payment_orders_on_user_id_and_status"
    t.index ["user_id"], name: "index_payment_orders_on_user_id"
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
    t.integer "total_resumes", default: 0
    t.float "average_ats_score", default: 0.0
    t.integer "total_companies", default: 0
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["profile_data"], name: "index_users_on_profile_data", using: :gin
  end

  add_foreign_key "coin_transactions", "users"
  add_foreign_key "customizations", "users"
  add_foreign_key "payment_orders", "users"
  add_foreign_key "resume_versions", "users"
end
