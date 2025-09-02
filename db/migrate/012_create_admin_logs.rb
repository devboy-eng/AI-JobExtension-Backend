class CreateAdminLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :admin_logs do |t|
      t.references :admin_user, foreign_key: true, null: true
      t.string :action, null: false
      t.text :details, null: false
      t.string :target_type
      t.bigint :target_id
      t.string :ip_address, null: false
      t.text :user_agent
      t.text :additional_data
      t.timestamps
    end
    
    add_index :admin_logs, [:target_type, :target_id]
    add_index :admin_logs, :action
    add_index :admin_logs, :created_at
    add_index :admin_logs, :admin_user_id
    add_index :admin_logs, :ip_address
  end
end