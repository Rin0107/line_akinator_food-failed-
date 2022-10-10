# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2022_10_10_025302) do

  create_table "latest_questions", force: :cascade do |t|
    t.integer "progress_id"
    t.integer "question_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["progress_id"], name: "index_latest_questions_on_progress_id"
    t.index ["question_id"], name: "index_latest_questions_on_question_id"
  end

  create_table "progresses", force: :cascade do |t|
    t.integer "user_status_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_status_id"], name: "index_progresses_on_user_status_id", unique: true
  end

  create_table "questions", force: :cascade do |t|
    t.text "message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "solutions", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_statuses", force: :cascade do |t|
    t.string "user_id"
    t.integer "status", limit: 1, default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
