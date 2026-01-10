FactoryBot.define do
  factory :coin_transaction do
    user { nil }
    amount { 1 }
    transaction_type { "MyString" }
    description { "MyString" }
    razorpay_order_id { "MyString" }
    razorpay_payment_id { "MyString" }
  end
end
