class AddFieldsToInstagramAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :instagram_accounts, :account_type, :string, default: 'PERSONAL'
    add_column :instagram_accounts, :media_count, :integer, default: 0
    add_column :instagram_accounts, :connected_at, :datetime
    
    # Remove unique constraint on instagram_user_id to allow multiple apps per user
    remove_index :instagram_accounts, :instagram_user_id if index_exists?(:instagram_accounts, :instagram_user_id)
    add_index :instagram_accounts, [:user_id, :instagram_user_id], unique: true
  end
end