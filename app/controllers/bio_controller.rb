class BioController < ApplicationController
  skip_before_action :authenticate_user!
  
  # GET /bio/:username
  # GET /bio/:user_id
  def show
    user = find_user_by_identifier(params[:id])
    
    if user.nil?
      return render json: {
        success: false,
        message: 'User not found'
      }, status: :not_found
    end
    
    links = user.links.active.ordered
    
    render json: {
      success: true,
      data: {
        user: {
          id: user.id,
          email: user.email.split('@').first, # Only show username part
          referral_code: user.referral_code,
          created_at: user.created_at
        },
        links: links.map { |link| public_link_json(link) },
        meta: {
          total_links: links.count,
          last_updated: links.maximum(:updated_at) || user.updated_at
        }
      }
    }
  end
  
  # GET /bio/:user_id/analytics (for future use)
  def analytics
    # This endpoint could be used to track click analytics
    # For now, just return basic stats
    render json: {
      success: true,
      data: {
        total_clicks: 0,
        unique_visitors: 0,
        top_links: []
      }
    }
  end
  
  private
  
  def find_user_by_identifier(identifier)
    # Try to find by ID first (numeric)
    if identifier.match?(/^\d+$/)
      User.find_by(id: identifier)
    else
      # Try to find by referral code or email username
      User.find_by(referral_code: identifier.upcase) ||
      User.joins('').where('LOWER(SPLIT_PART(email, \'@\', 1)) = ?', identifier.downcase).first
    end
  end
  
  def public_link_json(link)
    {
      id: link.id,
      title: link.title,
      url: link.url,
      description: link.description,
      position: link.position
    }
  end
end