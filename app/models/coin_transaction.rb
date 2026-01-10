class CoinTransaction < ApplicationRecord
  belongs_to :user

  validates :amount, presence: true, numericality: { other_than: 0 }
  validates :transaction_type, presence: true, inclusion: { in: %w[credit debit] }
  validates :description, presence: true

  scope :credits, -> { where(transaction_type: 'credit') }
  scope :debits, -> { where(transaction_type: 'debit') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }

  def credit?
    transaction_type == 'credit'
  end

  def debit?
    transaction_type == 'debit'
  end

  def display_amount
    credit? ? amount : -amount
  end
end