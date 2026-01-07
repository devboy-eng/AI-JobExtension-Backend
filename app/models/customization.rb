class Customization < ApplicationRecord
  belongs_to :user

  validates :job_title, presence: true
  validates :company, presence: true
  validates :resume_content, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_company, ->(company) { where(company: company) }
  scope :by_job_title, ->(title) { where(job_title: title) }
end