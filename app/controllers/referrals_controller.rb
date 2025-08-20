class ReferralsController < ApplicationController
  def stats
    render json: {
      totalReferrals: current_user.total_referrals,
      totalEarnings: current_user.referral_earnings,
      activeReferrals: current_user.active_referrals_count,
      pendingCommissions: current_user.pending_commissions
    }
  end
  
  def index
    referrals = current_user.referrals.select(
      :id, :first_name, :last_name, :email, :plan, :created_at
    ).order(created_at: :desc)
    
    render json: referrals.map { |referral|
      {
        id: referral.id,
        first_name: referral.first_name,
        last_name: referral.last_name,
        email: referral.email,
        plan: referral.plan,
        created_at: referral.created_at,
        email_verified: true # Assuming all emails are verified for now
      }
    }
  end
end