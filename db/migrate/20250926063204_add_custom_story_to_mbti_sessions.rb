class AddCustomStoryToMbtiSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :mbti_sessions, :custom_story, :jsonb, default: {}
    add_index :mbti_sessions, :custom_story, using: :gin
  end
end
