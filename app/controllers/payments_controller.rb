class PaymentsController < ApplicationController
  require 'razorpay'
  require 'securerandom'
  
  # Skip authentication for webhook and test
  skip_before_action :authenticate_user!, only: [:webhook, :verify_payment, :test_razorpay]
  
  # Initialize Razorpay order for payment
  def create_order
    begin
      amount = params[:amount].to_i  # Amount in INR
      coins = calculate_coins(amount)
      
      # Validate parameters
      if amount <= 0
        return render json: { 
          success: false, 
          error: 'Invalid amount' 
        }, status: :bad_request
      end
      
      # Check if Razorpay keys are configured
      if ENV['RAZORPAY_KEY_ID'].blank? || ENV['RAZORPAY_KEY_SECRET'].blank?
        Rails.logger.error "Razorpay keys not configured"
        return render json: { 
          success: false, 
          error: 'Payment gateway not configured. Please contact support.' 
        }, status: :service_unavailable
      end
      
      # Initialize Razorpay
      Razorpay.setup(ENV['RAZORPAY_KEY_ID'], ENV['RAZORPAY_KEY_SECRET'])
      
      # Create Razorpay order
      order_amount = amount * 100 # Convert to paisa
      receipt_id = "rcpt_#{current_user.id}_#{Time.now.to_i}"
      
      razorpay_order = Razorpay::Order.create(
        amount: order_amount,
        currency: 'INR',
        receipt: receipt_id,
        notes: {
          user_id: current_user.id,
          user_email: current_user.email,
          coins: coins,
          custom_amount: params[:customAmount] || false
        }
      )
      
      # Save order details for verification later
      payment_order = PaymentOrder.create!(
        user_id: current_user.id,
        razorpay_order_id: razorpay_order.id,
        amount: amount,
        coins: coins,
        currency: 'INR',
        status: 'created',
        receipt: receipt_id
      )
      
      # Return order details for frontend
      render json: {
        success: true,
        order: {
          id: razorpay_order.id,
          amount: order_amount,
          currency: 'INR',
          key_id: ENV['RAZORPAY_KEY_ID'],
          name: 'Job Extension',
          description: "Purchase #{coins} coins",
          prefill: {
            name: "#{current_user.first_name} #{current_user.last_name}".strip,
            email: current_user.email,
            contact: current_user.phone || ''
          },
          theme: {
            color: '#4F46E5'
          },
          modal: {
            ondismiss: 'handlePaymentDismiss'
          }
        },
        user_id: current_user.id,
        coins: coins,
        payment_order_id: payment_order.id
      }
      
    rescue Razorpay::Error => e
      Rails.logger.error "Razorpay error: #{e.message}"
      render json: { 
        success: false, 
        error: 'Failed to create payment order. Please try again.' 
      }, status: :internal_server_error
      
    rescue => e
      Rails.logger.error "Payment order creation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { 
        success: false, 
        error: 'Something went wrong. Please try again.' 
      }, status: :internal_server_error
    end
  end
  
  # Verify payment after Razorpay checkout
  def verify_payment
    begin
      payment_id = params[:razorpay_payment_id]
      order_id = params[:razorpay_order_id]
      signature = params[:razorpay_signature]
      
      # Verify signature
      if ENV['RAZORPAY_KEY_SECRET'].present?
        generated_signature = OpenSSL::HMAC.hexdigest(
          OpenSSL::Digest.new('sha256'),
          ENV['RAZORPAY_KEY_SECRET'],
          "#{order_id}|#{payment_id}"
        )
        
        unless Rack::Utils.secure_compare(signature, generated_signature)
          Rails.logger.error "Payment verification failed: Invalid signature"
          return render json: { 
            success: false, 
            error: 'Payment verification failed' 
          }, status: :unauthorized
        end
      end
      
     
      # Initialize Razorpay and fetch payment details
      Razorpay.setup(ENV['RAZORPAY_KEY_ID'], ENV['RAZORPAY_KEY_SECRET'])
      payment = Razorpay::Payment.fetch(payment_id)
      
      # Find the payment order
      payment_order = PaymentOrder.find_by(razorpay_order_id: order_id)
      
      if payment_order.nil?
        return render json: { 
          success: false, 
          error: 'Payment order not found' 
        }, status: :not_found
      end
      
      # Update payment order status
      payment_order.update!(
        razorpay_payment_id: payment_id,
        razorpay_signature: signature,
        status: 'paid',
        paid_at: Time.current
      )
      
      # Credit coins to user
      user = payment_order.user
      user.update!(coin_balance: (user.coin_balance || 0) + payment_order.coins)
      
      # Log the transaction
      Rails.logger.info "Payment successful: User #{user.id} credited with #{payment_order.coins} coins"
      
      render json: {
        success: true,
        message: 'Payment verified successfully',
        coins_credited: payment_order.coins,
        new_balance: user.coin_balance,
        payment: {
          id: payment_id,
          amount: payment.amount / 100,
          status: payment.status,
          method: payment.method,
          created_at: Time.at(payment.created_at)
        }
      }
      
    rescue Razorpay::Error => e
      Rails.logger.error "Razorpay verification error: #{e.message}"
      render json: { 
        success: false, 
        error: 'Payment verification failed' 
      }, status: :internal_server_error
      
    rescue => e
      Rails.logger.error "Payment verification failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { 
        success: false, 
        error: 'Payment verification failed' 
      }, status: :internal_server_error
    end
  end
  
  # Razorpay webhook endpoint
  def webhook
    begin
      # Verify webhook signature
      webhook_secret = ENV['RAZORPAY_WEBHOOK_SECRET']
      
      if webhook_secret.present?
        webhook_signature = request.headers['X-Razorpay-Signature']
        webhook_body = request.raw_post
        
        expected_signature = OpenSSL::HMAC.hexdigest(
          OpenSSL::Digest.new('sha256'),
          webhook_secret,
          webhook_body
        )
        
        unless Rack::Utils.secure_compare(webhook_signature, expected_signature)
          Rails.logger.error "Invalid webhook signature"
          return render json: { error: 'Invalid signature' }, status: :unauthorized
        end
      end
      
      # Process webhook payload
      payload = JSON.parse(request.body.read)
      event = payload['event']
      
      Rails.logger.info "Razorpay webhook received: #{event}"
      
      case event
      when 'payment.captured'
        handle_payment_captured(payload['payload']['payment']['entity'])
      when 'payment.failed'
        handle_payment_failed(payload['payload']['payment']['entity'])
      when 'order.paid'
        handle_order_paid(payload['payload']['order']['entity'])
      end
      
      render json: { status: 'ok' }
      
    rescue => e
      Rails.logger.error "Webhook processing failed: #{e.message}"
      render json: { error: 'Webhook processing failed' }, status: :internal_server_error
    end
  end
  
  # Get payment history
  def history
    payment_orders = current_user.payment_orders
                                 .includes(:user)
                                 .order(created_at: :desc)
                                 .limit(50)
    
    render json: {
      success: true,
      payments: payment_orders.map { |order| serialize_payment_order(order) }
    }
  end
  
  # Test Razorpay configuration
  def test_razorpay
    render json: {
      success: true,
      razorpay_configured: ENV['RAZORPAY_KEY_ID'].present? && ENV['RAZORPAY_KEY_SECRET'].present?,
      key_id_present: ENV['RAZORPAY_KEY_ID'].present?,
      key_secret_present: ENV['RAZORPAY_KEY_SECRET'].present?,
      key_id_preview: ENV['RAZORPAY_KEY_ID'].present? ? "#{ENV['RAZORPAY_KEY_ID'][0..7]}..." : nil,
      webhook_secret_present: ENV['RAZORPAY_WEBHOOK_SECRET'].present?,
      message: ENV['RAZORPAY_KEY_ID'].present? ? 'Razorpay is configured' : 'Razorpay keys not configured'
    }
  end
  
  private
  
  def calculate_coins(amount)
    # Pricing tiers
    case amount
    when 10
      100   # ₹10 = 100 coins
    when 50
      600   # ₹50 = 600 coins (20% bonus)
    when 100
      1300  # ₹100 = 1300 coins (30% bonus)
    when 500
      7500  # ₹500 = 7500 coins (50% bonus)
    when 1000
      16000 # ₹1000 = 16000 coins (60% bonus)
    else
      # Custom amount: 10 coins per rupee
      amount * 10
    end
  end
  
  def handle_payment_captured(payment_data)
    order_id = payment_data['order_id']
    payment_id = payment_data['id']
    
    payment_order = PaymentOrder.find_by(razorpay_order_id: order_id)
    return unless payment_order
    
    # Update payment order
    payment_order.update!(
      razorpay_payment_id: payment_id,
      status: 'captured',
      paid_at: Time.current
    )
    
    # Credit coins if not already credited
    if payment_order.status_was != 'paid' && payment_order.status_was != 'captured'
      user = payment_order.user
      user.update!(coin_balance: (user.coin_balance || 0) + payment_order.coins)
      
      Rails.logger.info "Payment captured via webhook: User #{user.id} credited with #{payment_order.coins} coins"
    end
  end
  
  def handle_payment_failed(payment_data)
    order_id = payment_data['order_id']
    payment_id = payment_data['id']
    
    payment_order = PaymentOrder.find_by(razorpay_order_id: order_id)
    return unless payment_order
    
    payment_order.update!(
      razorpay_payment_id: payment_id,
      status: 'failed'
    )
    
    Rails.logger.warn "Payment failed: Order #{order_id}, Payment #{payment_id}"
  end
  
  def handle_order_paid(order_data)
    order_id = order_data['id']
    
    payment_order = PaymentOrder.find_by(razorpay_order_id: order_id)
    return unless payment_order
    
    payment_order.update!(status: 'paid', paid_at: Time.current)
    
    # Credit coins if not already credited
    if payment_order.status_was != 'paid' && payment_order.status_was != 'captured'
      user = payment_order.user
      user.update!(coin_balance: (user.coin_balance || 0) + payment_order.coins)
      
      Rails.logger.info "Order paid via webhook: User #{user.id} credited with #{payment_order.coins} coins"
    end
  end
  
  def serialize_payment_order(order)
    {
      id: order.id,
      amount: order.amount,
      coins: order.coins,
      status: order.status,
      created_at: order.created_at,
      paid_at: order.paid_at,
      razorpay_order_id: order.razorpay_order_id,
      razorpay_payment_id: order.razorpay_payment_id
    }
  end
end