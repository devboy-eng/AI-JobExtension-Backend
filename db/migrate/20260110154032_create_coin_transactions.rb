class CreateCoinTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :coin_transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :amount, null: false
      t.string :transaction_type, null: false
      t.string :description, null: false
      t.string :razorpay_order_id
      t.string :razorpay_payment_id

      t.timestamps
    end

    add_index :coin_transactions, :razorpay_order_id
    add_index :coin_transactions, :razorpay_payment_id
    add_index :coin_transactions, :transaction_type
    add_index :coin_transactions, [:user_id, :created_at]
  end
end
