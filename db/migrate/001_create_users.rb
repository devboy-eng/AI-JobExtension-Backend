class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    # Only create if table doesn't exist (production-safe)
    unless table_exists?(:users)
      create_table :users do |t|
        t.string :email, null: false
        t.string :password_digest, null: false
        t.string :first_name
        t.string :last_name
        t.integer :plan, default: 0
        t.timestamps
      end
      
      add_index :users, :email, unique: true
    end
  end
end