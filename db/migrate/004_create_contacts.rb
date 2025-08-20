class CreateContacts < ActiveRecord::Migration[7.0]
  def change
    create_table :contacts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :instagram_username, null: false
      t.string :instagram_user_id, null: false
      t.string :full_name
      t.text :bio
      t.integer :followers_count
      t.timestamps
    end
    
    add_index :contacts, [:user_id, :instagram_user_id], unique: true
  end
end