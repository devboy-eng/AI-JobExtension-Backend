class AddCoinBalanceToUsers < ActiveRecord::Migration[7.1]
  def change
    # Only add if column doesn't exist (production-safe)
    unless column_exists?(:users, :coin_balance)
      add_column :users, :coin_balance, :integer, default: 0
    end
  end
end
