class AddStoryModeToMbtiSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :mbti_sessions, :story_mode, :string
  end
end
