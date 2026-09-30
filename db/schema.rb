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

ActiveRecord::Schema[8.1].define(version: 2026_09_30_000000) do
  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_accounts_on_email", unique: true
  end

  create_table "contact_requests", force: :cascade do |t|
    t.datetime "consented_at", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "intent", null: false
    t.text "message", null: false
    t.string "name", null: false
    t.integer "submission_id", null: false
    t.json "target_ids", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["submission_id"], name: "index_contact_requests_on_submission_id"
  end

  create_table "login_codes", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "digest", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.string "request_ip", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.index ["email", "created_at"], name: "index_login_codes_on_email_and_created_at"
    t.index ["request_ip", "created_at"], name: "index_login_codes_on_request_ip_and_created_at"
  end

  create_table "portfolio_images", force: :cascade do |t|
    t.string "content_type", null: false
    t.datetime "created_at", null: false
    t.binary "data", null: false
    t.integer "submission_id"
    t.datetime "updated_at", null: false
    t.string "upload_owner", null: false
    t.index ["submission_id"], name: "index_portfolio_images_on_submission_id"
    t.index ["upload_owner", "created_at"], name: "index_portfolio_images_on_upload_owner_and_created_at"
  end

  create_table "submissions", force: :cascade do |t|
    t.integer "account_id"
    t.text "availability", null: false
    t.text "challenge"
    t.datetime "consented_at", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "engagement", null: false
    t.text "experience"
    t.string "kind", null: false
    t.text "location", null: false
    t.string "name", null: false
    t.text "notes"
    t.string "organisation_name"
    t.text "pay_expectations", null: false
    t.json "profile", default: {}, null: false
    t.integer "profile_version", default: 1, null: false
    t.string "public_slug"
    t.boolean "published", default: true, null: false
    t.text "purpose", null: false
    t.string "status", default: "Received", null: false
    t.datetime "updated_at", null: false
    t.string "website"
    t.string "working_style", null: false
    t.index ["account_id"], name: "index_submissions_on_account_id", unique: true
    t.index ["kind", "created_at"], name: "index_submissions_on_kind_and_created_at"
    t.index ["public_slug"], name: "index_submissions_on_public_slug", unique: true
    t.index ["status"], name: "index_submissions_on_status"
  end

  add_foreign_key "contact_requests", "submissions"
  add_foreign_key "portfolio_images", "submissions"
  add_foreign_key "submissions", "accounts"
end
