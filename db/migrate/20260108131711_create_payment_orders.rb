class CreatePaymentOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :payment_orders do |t|
      t.references :user, null: false, foreign_key: true
      t.string :razorpay_order_id, null: false, index: { unique: true }
      t.string :razorpay_payment_id, index: true
      t.string :razorpay_signature
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.integer :coins, null: false
      t.string :currency, null: false, default: 'INR'
      t.string :receipt
      t.integer :status, default: 0, null: false, index: true
      t.datetime :paid_at
      t.json :metadata

      t.timestamps
    end
    
    add_index :payment_orders, [:user_id, :status]
    add_index :payment_orders, :created_at
  end
end