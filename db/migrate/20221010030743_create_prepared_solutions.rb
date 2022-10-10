class CreatePreparedSolutions < ActiveRecord::Migration[5.2]
  def change
    create_table :prepared_solutions do |t|

      t.timestamps
    end
  end
end
