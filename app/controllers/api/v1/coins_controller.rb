module Api
  module V1
    class CoinsController < ApplicationController
      before_action :authenticate_user!

      def balance
        begin
          if current_user && User.column_names.include?('coin_balance')
            # Use database storage
            balance = current_user.coin_balance || 0
            free_credits = current_user.plan == 'free' ? 10 : 0
          else
            # Fallback values
            balance = 100
            free_credits = 10
          end

          render json: {
            success: true,
            balance: balance,
            free_credits: free_credits,
            total_available: balance + free_credits
          }
        rescue => e
          Rails.logger.error("Error getting coin balance: #{e.message}")
          render json: {
            success: false,
            error: 'Failed to get balance',
            balance: 0,
            free_credits: 0,
            total_available: 0
          }, status: 500
        end
      end

      def transactions
        transactions = current_user.coin_transactions
                                   .recent
                                   .limit(params[:limit] || 50)

        render json: {
          success: true,
          transactions: transactions.map { |transaction| serialize_transaction(transaction) }
        }
      end

      private

      def serialize_transaction(transaction)
        {
          id: transaction.id,
          amount: transaction.display_amount,
          type: transaction.transaction_type,
          description: transaction.description,
          timestamp: transaction.created_at.iso8601,
          created_at: transaction.created_at.iso8601,
          razorpay_order_id: transaction.razorpay_order_id,
          razorpay_payment_id: transaction.razorpay_payment_id
        }.compact
      end
    end
  end
end