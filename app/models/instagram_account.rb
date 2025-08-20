class InstagramAccount < ApplicationRecord
  belongs_to :user
  has_many :automations, dependent: :destroy
  
  validates :instagram_user_id, presence: true, uniqueness: true
  validates :username, presence: true
  validates :access_token, presence: true
  
  def refresh_access_token!
    # Instagram Basic Display API token refresh logic
    response = Faraday.post("https://graph.instagram.com/refresh_access_token") do |req|
      req.params['grant_type'] = 'ig_refresh_token'
      req.params['access_token'] = access_token
    end
    
    if response.success?
      data = JSON.parse(response.body)
      update!(
        access_token: data['access_token'],
        token_expires_at: Time.current + data['expires_in'].seconds
      )
    end
  end
  
  def token_expired?
    token_expires_at && token_expires_at < Time.current
  end
end