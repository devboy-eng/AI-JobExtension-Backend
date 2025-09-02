class User < ApplicationRecord
  has_secure_password
  
  has_many :instagram_accounts, dependent: :destroy
  has_many :automations, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :usage_metrics, dependent: :destroy
  has_many :user_logs, dependent: :destroy
  has_many :referrals, class_name: 'User', foreign_key: 'referred_by'
  belongs_to :referrer, class_name: 'User', foreign_key: 'referred_by', optional: true
  
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, if: -> { password.present? }
  validates :referral_code, uniqueness: true, allow_nil: true
  
  enum plan: { free: 0, pro: 1, monthly_pro: 2, annual_pro: 3, custom: 4 }
  
  before_create :generate_referral_code
  
  def current_month_dm_count
    usage_metrics.where(
      metric_type: 'dm_sent',
      created_at: Time.current.beginning_of_month..Time.current.end_of_month
    ).sum(:count)
  end
  
  def current_month_contact_count
    contacts.where(
      created_at: Time.current.beginning_of_month..Time.current.end_of_month
    ).count
  end
  
  def dm_limit
    case plan
    when 'free'
      1000
    when 'pro', 'monthly_pro', 'annual_pro'
      Float::INFINITY # Unlimited
    when 'custom'
      custom_dm_limit || 1000
    else
      1000
    end
  end
  
  def contact_limit
    case plan
    when 'free'
      1000
    when 'pro', 'monthly_pro', 'annual_pro'
      Float::INFINITY # Unlimited
    when 'custom'
      custom_contact_limit || 1000
    else
      1000
    end
  end
  
  def is_pro_user?
    %w[pro monthly_pro annual_pro custom].include?(plan)
  end
  
  def referral_link
    "https://kuposu.co?ref=#{referral_code}"
  end
  
  def active_referrals_count
    referrals.where('created_at >= ?', 30.days.ago).count
  end
  
  def pending_commissions
    # Calculate 30% commission from referrals' payments
    # This would need to be implemented based on your payment system
    referrals.sum { |referral| referral.total_paid * 0.30 }
  end
  
  private
  
  def generate_referral_code
    loop do
      self.referral_code = SecureRandom.hex(4).upcase
      break unless User.exists?(referral_code: referral_code)
    end
  end
end