class Permission < ApplicationRecord
  has_many :role_permissions, dependent: :destroy
  has_many :roles, through: :role_permissions
  
  validates :name, presence: true, uniqueness: true
  validates :resource, presence: true
  validates :action, presence: true
  validates :description, presence: true
  
  scope :by_resource, ->(resource) { where(resource: resource) }
  scope :by_action, ->(action) { where(action: action) }
  
  before_validation :normalize_attributes
  
  RESOURCES = %w[
    dashboard users roles automations analytics financial 
    support settings security billing admin_users
  ].freeze
  
  ACTIONS = %w[
    view create edit delete export suspend activate 
    impersonate assign manage permissions
  ].freeze
  
  def self.seed_permissions
    RESOURCES.each do |resource|
      ACTIONS.each do |action|
        next if exists?(name: "#{resource}.#{action}")
        
        create!(
          name: "#{resource}.#{action}",
          resource: resource,
          action: action,
          description: "Can #{action} #{resource.humanize.downcase}"
        )
      end
    end
  end
  
  def full_name
    "#{resource.humanize} - #{action.humanize}"
  end
  
  def key
    "#{resource}.#{action}"
  end
  
  private
  
  def normalize_attributes
    self.name = name&.strip&.downcase
    self.resource = resource&.strip&.downcase
    self.action = action&.strip&.downcase
  end
end