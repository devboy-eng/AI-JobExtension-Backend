class User < ApplicationRecord
  has_secure_password
  
  # Job Extension specific associations
  has_many :resume_versions, dependent: :destroy
  has_many :customizations, dependent: :destroy
  has_many :payment_orders, dependent: :destroy
  
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, if: -> { password.present? }
  enum plan: { free: 0, pro: 1, monthly_pro: 2, annual_pro: 3, custom: 4 }
  before_create :initialize_profile_data
  
  # Helper methods for profile data
  def get_profile_field(field)
    return nil unless self.class.column_names.include?('profile_data')
    (profile_data || {})[field.to_s]
  end
  
  def set_profile_field(field, value)
    return unless self.class.column_names.include?('profile_data')
    self.profile_data = (profile_data || {}).merge(field.to_s => value)
  end
  
  def is_pro_user?
    %w[pro monthly_pro annual_pro custom].include?(plan)
  end

  # Coin management methods
  def deduct_coins(amount, description = nil)
    return false if coin_balance < amount
    
    update!(coin_balance: coin_balance - amount)
    true
  rescue => e
    Rails.logger.error "Error deducting coins for user #{id}: #{e.message}"
    false
  end

  def add_coins(amount, description = nil)
    update!(coin_balance: coin_balance + amount)
    true
  rescue => e
    Rails.logger.error "Error adding coins for user #{id}: #{e.message}"
    false
  end

  # Legacy methods for DM and contact usage (placeholders for compatibility)
  def current_month_dm_count
    0 # Placeholder since we removed Instagram automation
  end

  def dm_limit
    is_pro_user? ? 1000 : 100
  end

  def current_month_contact_count
    0 # Placeholder since we removed Instagram automation
  end

  def contact_limit
    is_pro_user? ? 500 : 50
  end

  # Legacy referral system (placeholder for compatibility)
  def referral_code
    "REF#{id}#{email[0..2].upcase}" # Generate simple referral code
  end
  
  private
  
  def initialize_profile_data
    # Only set profile_data if the column exists
    if self.class.column_names.include?('profile_data')
      self.profile_data ||= {}
    end
  end
end