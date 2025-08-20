class CreateInstagramAccounts < ActiveRecord::Migration[7.0]
  def change
    create_table :instagram_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :instagram_user_id, null: false
      t.string :username, null: false
      t.text :access_token, null: false
      t.datetime :token_expires_at
      t.timestamps
    end
    
    add_index :instagram_accounts, :instagram_user_id, unique: true
  end
end