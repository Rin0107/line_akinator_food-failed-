class CreateAnswers < ActiveRecord::Migration[5.2]
  def change
    create_table :answers do |t|
      t.belongs_to :progress, index: true, foreign_key: true
      t.belongs_to :question, index: true, foreign_key: true
      t.float :value
      t.timestamps
    end
  end
end
