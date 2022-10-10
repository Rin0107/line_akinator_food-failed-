class CreatePreparedSolutions < ActiveRecord::Migration[5.2]
  def change
    create_table :prepared_solutions do |t|
      t.belongs_to :progress, index: { unique: true }, foreign_key: true
      t.string :name
      t.timestamps
    end
  end
end
