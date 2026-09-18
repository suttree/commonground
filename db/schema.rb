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

ActiveRecord::Schema[8.1].define(version: 2026_09_18_000100) do
  create_table "submissions", force: :cascade do |t|
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
    t.text "purpose", null: false
    t.string "status", default: "Received", null: false
    t.datetime "updated_at", null: false
    t.string "website"
    t.string "working_style", null: false
    t.index ["kind", "created_at"], name: "index_submissions_on_kind_and_created_at"
    t.index ["status"], name: "index_submissions_on_status"
  end
end
