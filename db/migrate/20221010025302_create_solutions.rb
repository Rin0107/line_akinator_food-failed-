class CreateSolutions < ActiveRecord::Migration[5.2]
  def change
    create_table :solutions do |t|
      t.string :name
      t.timestamps
    end
    add_index :solutions, [:name], unipue: true
  end
end
