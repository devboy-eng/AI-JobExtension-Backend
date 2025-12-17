class Link < ApplicationRecord
  belongs_to :user
  
  validates :title, presence: true, length: { maximum: 100 }
  validates :url, presence: true, format: { with: URI::regexp(%w[http https]), message: 'must be a valid URL' }
  validates :description, length: { maximum: 500 }
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position) }
  scope :for_user, ->(user) { where(user: user) }
  
  before_create :set_default_position
  
  private
  
  def set_default_position
    return if position.present?
    
    max_position = user.links.maximum(:position) || -1
    self.position = max_position + 1
  end
end
