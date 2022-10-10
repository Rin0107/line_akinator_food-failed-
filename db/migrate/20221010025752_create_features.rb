class CreateFeatures < ActiveRecord::Migration[5.2]
  def change
    create_table :features do |t|
      t.belongs_to :question, index: true, foreign_key: true
      t.belongs_to :solution, index: true, foreign_key: true
      t.float :value
      t.timestamps
    end
  end
end
