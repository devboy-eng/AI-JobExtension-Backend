class ResumeVersion < ApplicationRecord
  belongs_to :user
  
  validates :job_title, presence: true
  validates :company, presence: true
  validates :resume_content, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
end
