class AddStoryStateToMbtiSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :mbti_sessions, :story_state, :jsonb, default: {}
    add_index :mbti_sessions, :story_state, using: :gin
  end
end
