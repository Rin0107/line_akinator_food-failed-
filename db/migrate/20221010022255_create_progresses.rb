class CreateProgresses < ActiveRecord::Migration[5.2]
  def change
    create_table :progresses do |t|
      t.belongs_to :user_status, index: { unique: true }, foreign_key: true
      t.timestamps
    end
  end
end
