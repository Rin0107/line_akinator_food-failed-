class CreateSolutions < ActiveRecord::Migration[5.2]
  def change
    create_table :solutions do |t|
      t.string :name, index: { unique: true }
      t.timestamps
    end
  end
end
