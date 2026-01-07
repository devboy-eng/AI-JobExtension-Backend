class AddProfileDataToUsers < ActiveRecord::Migration[7.1]
  def change
    # Only add if column doesn't exist (production-safe)
    unless column_exists?(:users, :profile_data)
      add_column :users, :profile_data, :jsonb, default: {}
      add_index :users, :profile_data, using: :gin
    end
  end
end