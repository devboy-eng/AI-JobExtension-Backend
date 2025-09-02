class CreateAdminUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :admin_users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.integer :status, default: 0
      t.references :role, null: false, foreign_key: true
      t.datetime :last_sign_in_at
      t.string :last_sign_in_ip
      t.timestamps
    end
    
    add_index :admin_users, :email, unique: true
    add_index :admin_users, :status
  end
end