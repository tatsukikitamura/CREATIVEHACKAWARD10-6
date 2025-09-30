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

ActiveRecord::Schema[7.1].define(version: 2025_09_26_063204) do
  create_table "mbti_sessions", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "questions"
    t.text "answers"
    t.integer "current_question_index", default: 0
    t.boolean "completed", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "story_mode"
    t.json "story_state", default: {}
    t.json "custom_story", default: {}
    t.index ["custom_story"], name: "index_mbti_sessions_on_custom_story", using: :gin
    t.index ["session_id"], name: "index_mbti_sessions_on_session_id", unique: true
    t.index ["story_state"], name: "index_mbti_sessions_on_story_state", using: :gin
  end

end
