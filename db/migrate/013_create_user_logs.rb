class CreateUserLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :user_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :admin_user, foreign_key: true, null: true
      t.string :action, null: false
      t.text :details, null: false
      t.string :ip_address
      t.text :user_agent
      t.text :additional_data
      t.timestamps
    end
    
    add_index :user_logs, :action
    add_index :user_logs, :created_at
    add_index :user_logs, [:user_id, :action]
    add_index :user_logs, [:user_id, :created_at]
  end
end