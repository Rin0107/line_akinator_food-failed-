class CreateUserStatuses < ActiveRecord::Migration[5.2]
  def change
    create_table :user_statuses do |t|
      t.string :user_id
      t.integer :status, default: 0, limit: 1
      t.timestamps
    end
  end
end
