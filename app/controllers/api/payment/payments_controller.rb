class Api::Payment::PaymentsController < ApplicationController
  require 'securerandom'
  
  # Skip authentication for development testing
  skip_before_action :authenticate_user!, if: -> { Rails.env.development? }
  
  def create_order
    begin
      if Rails.env.development?
        # For development, create or use a test user
        user = User.find_or_create_by(email: 'test@example.com') do |u|
          u.password = 'password'
          u.coin_balance = 0
        end
      else
        # Use existing authentication in production
        authenticate_user!
        user = current_user
      end
      
      amount = params[:amount].to_i
      coins = params[:coins].to_i
      
      # Validate parameters
      return render json: { success: false, error: 'Invalid amount or coins' }, status: :bad_request if amount <= 0 || coins <= 0
      
      # Check if Razorpay is configured
      if Rails.application.credentials.razorpay[:key_id].blank? || Rails.application.credentials.razorpay[:key_secret].blank?
        # Return mock payment for development
        # Credit coins to user for testing
        user.update(coin_balance: (user.coin_balance || 0) + coins)
        
        render json: {
          success: true,
          mock: true,
          message: 'Mock payment successful - Razorpay not configured',
          coins_credited: coins,
          new_balance: user.coin_balance
        }
        return
      end
      
      # Initialize Razorpay (when properly configured)
      require 'razorpay'
      Razorpay.setup(Rails.application.credentials.razorpay[:key_id], Rails.application.credentials.razorpay[:key_secret])
      
      # Create Razorpay order
      order_amount = amount * 100 # Convert to paisa
      order = Razorpay::Order.create(
        amount: order_amount,
        currency: 'INR',
        receipt: "receipt_#{SecureRandom.hex(8)}",
        notes: {
          user_id: user.id,
          coins: coins
        }
      )
      
      render json: {
        success: true,
        order: {
          id: order.id,
          amount: order.amount,
          currency: order.currency,
          key_id: Rails.application.credentials.razorpay[:key_id]
        },
        user_id: user.id,
        coins: coins
      }
      
    rescue => e
      Rails.logger.error "Payment order creation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { success: false, error: 'Payment order creation failed' }, status: :internal_server_error
    end
  end
  
  def webhook
    begin
      # Verify webhook signature (when Razorpay is configured)
      if Rails.application.credentials.razorpay[:webhook_secret].present?
        # Verify Razorpay signature
        webhook_signature = request.headers['X-Razorpay-Signature']
        webhook_body = request.raw_post
        
        expected_signature = OpenSSL::HMAC.hexdigest(
          OpenSSL::Digest.new('sha256'),
          Rails.application.credentials.razorpay[:webhook_secret],
          webhook_body
        )
        
        unless Rack::Utils.secure_compare(webhook_signature, expected_signature)
          return render json: { error: 'Invalid signature' }, status: :unauthorized
        end
      end
      
      # Process webhook payload
      payload = JSON.parse(request.body.read)
      event = payload['event']
      
      case event
      when 'payment.captured'
        handle_payment_success(payload['payload']['payment']['entity'])
      when 'payment.failed'
        handle_payment_failure(payload['payload']['payment']['entity'])
      end
      
      render json: { success: true }
      
    rescue => e
      Rails.logger.error "Webhook processing failed: #{e.message}"
      render json: { error: 'Webhook processing failed' }, status: :internal_server_error
    end
  end
  
  private
  
  def handle_payment_success(payment_data)
    # Extract user_id and coins from payment notes or order
    order_id = payment_data['order_id']
    
    if Rails.application.credentials.razorpay[:key_id].present?
      # When Razorpay is configured, fetch order details
      Razorpay.setup(Rails.application.credentials.razorpay[:key_id], Rails.application.credentials.razorpay[:key_secret])
      order = Razorpay::Order.fetch(order_id)
      
      user_id = order.notes['user_id']
      coins = order.notes['coins'].to_i
      amount = order.amount.to_f / 100  # Convert from paise to rupees
    else
      # For mock payments, extract from payment_data
      user_id = payment_data['notes']['user_id']
      coins = payment_data['notes']['coins'].to_i
      amount = payment_data['amount'].to_f / 100
    end
    
    # Credit coins to user
    user = User.find(user_id)
    user.update(coin_balance: (user.coin_balance || 0) + coins)
    
    # Send payment confirmation email
    begin
      UserMailer.payment_confirmation(
        user, 
        order_id, 
        amount, 
        coins, 
        'Razorpay'
      ).deliver_now
      Rails.logger.info "Payment confirmation email sent to #{user.email}"
    rescue => e
      Rails.logger.error "Failed to send payment confirmation email: #{e.message}"
    end
    
    Rails.logger.info "Payment successful: User #{user_id} credited with #{coins} coins"
  end
  
  def handle_payment_failure(payment_data)
    Rails.logger.warn "Payment failed: #{payment_data['id']}"
    # Handle payment failure if needed
  end
end