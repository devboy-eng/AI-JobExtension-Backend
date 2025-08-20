class Automation < ApplicationRecord
  belongs_to :user
  belongs_to :instagram_account
  
  validates :trigger_keyword, presence: true
  validates :response_message, presence: true
  validates :name, presence: true
  
  enum status: { active: 0, inactive: 1, paused: 2 }
  
  scope :active, -> { where(status: :active) }
end