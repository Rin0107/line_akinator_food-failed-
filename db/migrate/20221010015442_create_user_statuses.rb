class CreateUserStatuses < ActiveRecord::Migration[5.2]
  def change
    create_table :user_statuses do |t|
      t.string :user_id

      t.timestamps
    end
  end
end
