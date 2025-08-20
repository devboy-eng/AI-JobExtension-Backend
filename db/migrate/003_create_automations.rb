class CreateAutomations < ActiveRecord::Migration[7.0]
  def change
    create_table :automations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :instagram_account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :trigger_keyword, null: false
      t.text :response_message, null: false
      t.integer :status, default: 0
      t.timestamps
    end
  end
end