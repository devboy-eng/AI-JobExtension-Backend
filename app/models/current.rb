class Current < ActiveSupport::CurrentAttributes
  attribute :user, :admin_user, :ip_address, :user_agent, :request_id
  
  def self.set_from_request(request)
    self.ip_address = request.remote_ip
    self.user_agent = request.user_agent
    self.request_id = request.request_id
  end
  
  def self.clear_context
    reset
  end
end