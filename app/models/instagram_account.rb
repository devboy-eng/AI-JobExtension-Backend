class InstagramAccount < ApplicationRecord
  belongs_to :user
  
  validates :instagram_user_id, :username, :access_token, presence: true
  validates :instagram_user_id, uniqueness: { scope: :user_id }
  
  scope :active, -> { where('token_expires_at > ?', Time.current) }
  
  def token_expired?
    token_expires_at && token_expires_at <= Time.current
  end
  
  def expires_soon?
    token_expires_at && token_expires_at <= 7.days.from_now
  end
end