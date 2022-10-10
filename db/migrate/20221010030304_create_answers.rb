class CreateAnswers < ActiveRecord::Migration[5.2]
  def change
    create_table :answers do |t|
      t.belongs_to :answer
      t.belongs_to :question
      t.float :value
      t.timestamps
    end
  end
end
