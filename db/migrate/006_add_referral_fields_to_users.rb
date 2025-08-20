class AddReferralFieldsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :referral_code, :string
    add_column :users, :referred_by, :integer
    add_column :users, :referral_earnings, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :users, :total_referrals, :integer, default: 0
    
    add_index :users, :referral_code, unique: true
    add_index :users, :referred_by
  end
end