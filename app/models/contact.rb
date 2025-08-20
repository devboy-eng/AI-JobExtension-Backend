class Contact < ApplicationRecord
  belongs_to :user
  
  validates :instagram_username, presence: true
  validates :instagram_user_id, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
end