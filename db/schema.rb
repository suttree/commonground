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

ActiveRecord::Schema[8.1].define(version: 2026_10_26_203627) do
  create_table "accounts", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.json "onboarding", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_accounts_on_email", unique: true
  end

  create_table "challenges", force: :cascade do |t|
    t.text "approach"
    t.json "collaborator_ids", default: [], null: false
    t.datetime "completed_at"
    t.text "context"
    t.datetime "created_at", null: false
    t.text "description"
    t.json "help_options", default: [], null: false
    t.string "industry"
    t.string "location"
    t.text "objectives"
    t.integer "organisation_id"
    t.string "organisation_name"
    t.string "project_role"
    t.string "project_url"
    t.datetime "published_at"
    t.text "results"
    t.string "status", default: "draft", null: false
    t.integer "submission_id", null: false
    t.text "target"
    t.json "target_ids", default: [], null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["organisation_id"], name: "index_challenges_on_organisation_id"
    t.index ["status", "published_at"], name: "index_challenges_on_status_and_published_at"
    t.index ["submission_id"], name: "index_challenges_on_submission_id"
    t.index ["submission_id"], name: "one_active_challenge_per_profile", unique: true, where: "status = 'active'"
  end

  create_table "collaborator_invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.integer "challenge_id", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.datetime "reminded_at"
    t.datetime "revoked_at"
    t.datetime "sent_at"
    t.string "short_token"
    t.datetime "updated_at", null: false
    t.index ["challenge_id", "email"], name: "index_collaborator_invitations_on_challenge_id_and_email"
    t.index ["challenge_id"], name: "index_collaborator_invitations_on_challenge_id"
    t.index ["short_token"], name: "index_collaborator_invitations_on_short_token", unique: true
  end

  create_table "contact_requests", force: :cascade do |t|
    t.integer "challenge_id"
    t.datetime "consented_at", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "intent", null: false
    t.text "message", null: false
    t.string "name", null: false
    t.integer "submission_id", null: false
    t.json "target_ids", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["challenge_id"], name: "index_contact_requests_on_challenge_id"
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
    t.integer "side_project_id"
    t.integer "submission_id"
    t.datetime "updated_at", null: false
    t.string "upload_owner", null: false
    t.index ["side_project_id"], name: "index_portfolio_images_on_side_project_id"
    t.index ["submission_id"], name: "index_portfolio_images_on_submission_id"
    t.index ["upload_owner", "created_at"], name: "index_portfolio_images_on_upload_owner_and_created_at"
  end

  create_table "profile_photos", force: :cascade do |t|
    t.string "content_type", null: false
    t.datetime "created_at", null: false
    t.binary "data", null: false
    t.integer "submission_id"
    t.datetime "updated_at", null: false
    t.string "upload_owner", null: false
    t.index ["submission_id"], name: "index_profile_photos_on_submission_id", unique: true
    t.index ["upload_owner", "created_at"], name: "index_profile_photos_on_upload_owner_and_created_at"
  end

  create_table "provocation_answers", force: :cascade do |t|
    t.string "choice", null: false
    t.datetime "created_at", null: false
    t.integer "provocation_id", null: false
    t.integer "submission_id", null: false
    t.datetime "updated_at", null: false
    t.index ["provocation_id"], name: "index_provocation_answers_on_provocation_id"
    t.index ["submission_id", "provocation_id"], name: "index_provocation_answers_on_submission_id_and_provocation_id", unique: true
    t.index ["submission_id"], name: "index_provocation_answers_on_submission_id"
    t.check_constraint "choice IN ('strong_no', 'no', 'yes', 'strong_yes')", name: "provocation_answer_choice"
  end

  create_table "provocations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "goal_id", null: false
    t.string "key", null: false
    t.integer "position", null: false
    t.text "question", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_provocations_on_key", unique: true
  end

  create_table "side_projects", force: :cascade do |t|
    t.integer "cover_image_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.text "joy"
    t.string "name", null: false
    t.text "purpose"
    t.integer "submission_id", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["submission_id"], name: "index_side_projects_on_submission_id"
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
    t.index ["account_id"], name: "index_submissions_on_account_id"
    t.index ["account_id"], name: "one_person_profile_per_account", unique: true, where: "kind = 'person'"
    t.index ["kind", "created_at"], name: "index_submissions_on_kind_and_created_at"
    t.index ["public_slug"], name: "index_submissions_on_public_slug", unique: true
    t.index ["status"], name: "index_submissions_on_status"
  end

  add_foreign_key "challenges", "submissions"
  add_foreign_key "challenges", "submissions", column: "organisation_id", on_delete: :nullify
  add_foreign_key "collaborator_invitations", "challenges"
  add_foreign_key "contact_requests", "challenges"
  add_foreign_key "contact_requests", "submissions"
  add_foreign_key "portfolio_images", "side_projects"
  add_foreign_key "portfolio_images", "submissions"
  add_foreign_key "profile_photos", "submissions"
  add_foreign_key "provocation_answers", "provocations"
  add_foreign_key "provocation_answers", "submissions"
  add_foreign_key "side_projects", "submissions"
  add_foreign_key "submissions", "accounts"
end
