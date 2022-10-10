class CreateLatestQuestions < ActiveRecord::Migration[5.2]
  def change
    create_table :latest_questions do |t|

      t.timestamps
    end
  end
end
