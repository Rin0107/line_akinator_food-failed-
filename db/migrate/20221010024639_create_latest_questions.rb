class CreateLatestQuestions < ActiveRecord::Migration[5.2]
  def change
    create_table :latest_questions do |t|
      t.belongs_to :progress
      t.belongs_to :question
      t.timestamps
    end
  end
end
