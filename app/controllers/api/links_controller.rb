class Api::LinksController < ApplicationController
  before_action :authenticate_user!, except: [:public_links]
  before_action :set_link, only: [:show, :update, :destroy]
  
  # GET /api/links
  def index
    @links = current_user.links.ordered
    render json: {
      success: true,
      data: @links.map { |link| link_json(link) }
    }
  end
  
  # GET /api/links/:id
  def show
    render json: {
      success: true,
      data: link_json(@link)
    }
  end
  
  # POST /api/links
  def create
    @link = current_user.links.build(link_params)
    
    if @link.save
      render json: {
        success: true,
        message: 'Link created successfully',
        data: link_json(@link)
      }, status: :created
    else
      render json: {
        success: false,
        message: 'Failed to create link',
        errors: @link.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  # PATCH/PUT /api/links/:id
  def update
    if @link.update(link_params)
      render json: {
        success: true,
        message: 'Link updated successfully',
        data: link_json(@link)
      }
    else
      render json: {
        success: false,
        message: 'Failed to update link',
        errors: @link.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  # DELETE /api/links/:id
  def destroy
    @link.destroy
    render json: {
      success: true,
      message: 'Link deleted successfully'
    }
  end
  
  # POST /api/links/reorder
  def reorder
    link_orders = params[:link_orders] || []
    
    ActiveRecord::Base.transaction do
      link_orders.each_with_index do |link_data, index|
        link = current_user.links.find(link_data[:id])
        link.update!(position: index)
      end
    end
    
    render json: {
      success: true,
      message: 'Links reordered successfully'
    }
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      message: 'One or more links not found'
    }, status: :not_found
  rescue => e
    render json: {
      success: false,
      message: 'Failed to reorder links',
      error: e.message
    }, status: :unprocessable_entity
  end
  
  # GET /api/links/public/:user_id
  def public_links
    user = User.find(params[:user_id])
    links = user.links.active.ordered
    
    render json: {
      success: true,
      data: {
        user: {
          id: user.id,
          email: user.email,
          created_at: user.created_at
        },
        links: links.map { |link| public_link_json(link) }
      }
    }
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      message: 'User not found'
    }, status: :not_found
  end
  
  private
  
  def set_link
    @link = current_user.links.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      message: 'Link not found'
    }, status: :not_found
  end
  
  def link_params
    params.require(:link).permit(:title, :url, :description, :position, :active)
  end
  
  def link_json(link)
    {
      id: link.id,
      title: link.title,
      url: link.url,
      description: link.description,
      position: link.position,
      active: link.active,
      created_at: link.created_at,
      updated_at: link.updated_at
    }
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