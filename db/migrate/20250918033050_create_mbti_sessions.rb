class CreateMbtiSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :mbti_sessions do |t|
      t.string :session_id, null: false
      t.text :questions
      t.text :answers
      t.integer :current_question_index, default: 0
      t.boolean :completed, default: false

      t.timestamps
    end
    
    add_index :mbti_sessions, :session_id, unique: true
  end
end
