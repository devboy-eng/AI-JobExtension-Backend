class PaymentOrder < ApplicationRecord
  belongs_to :user
  
  validates :razorpay_order_id, presence: true, uniqueness: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :coins, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :status, presence: true
  
  enum status: {
    created: 0,
    pending: 1,
    paid: 2,
    captured: 3,
    failed: 4,
    refunded: 5
  }
  
  scope :successful, -> { where(status: [:paid, :captured]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  
  def successful?
    paid? || captured?
  end
  
  def pending?
    created? || self.pending?
  end
end