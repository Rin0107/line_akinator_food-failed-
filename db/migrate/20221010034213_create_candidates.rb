class CreateCandidates < ActiveRecord::Migration[5.2]
  def change
    create_table :candidates do |t|
      t.belongs_to :progress
      t.belongs_to :solution
      t.timestamps
    end
  end
end
