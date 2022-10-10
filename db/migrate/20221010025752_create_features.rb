class CreateFeatures < ActiveRecord::Migration[5.2]
  def change
    create_table :features do |t|
      t.belongs_to :question
      t.belongs_to :solution
      t.float :value
      t.timestamps
    end
  end
end
