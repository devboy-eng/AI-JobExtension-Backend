class UsageMetric < ApplicationRecord
  belongs_to :user
  
  validates :metric_type, presence: true, inclusion: { in: %w[dm_sent contact_added] }
  validates :count, presence: true, numericality: { greater_than: 0 }
  
  scope :dm_sent, -> { where(metric_type: 'dm_sent') }
  scope :contact_added, -> { where(metric_type: 'contact_added') }
  scope :current_month, -> { where(created_at: Time.current.beginning_of_month..Time.current.end_of_month) }
end