class AddCoinBalanceToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :coin_balance, :integer, default: 0
  end
end
